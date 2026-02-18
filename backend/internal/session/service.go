package session

import (
	"context"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/database"
	lk "educonnect/pkg/livekit"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrSessionNotFound = errors.New("session not found")
	ErrUnauthorized    = errors.New("unauthorized action on session")
	ErrInvalidStatus   = errors.New("invalid session status for this action")
)

type Service struct {
	db      *database.Postgres
	livekit *lk.Client
}

func NewService(db *database.Postgres, livekit *lk.Client) *Service {
	return &Service{db: db, livekit: livekit}
}

// CreateSession creates a new tutoring session.
func (s *Service) CreateSession(ctx context.Context, teacherID string, req CreateSessionRequest) (*SessionResponse, error) {
	tuid, err := uuid.Parse(teacherID)
	if err != nil {
		return nil, fmt.Errorf("invalid teacher id: %w", err)
	}

	startTime, err := time.Parse(time.RFC3339, req.StartTime)
	if err != nil {
		return nil, fmt.Errorf("invalid start_time: %w", err)
	}
	endTime, err := time.Parse(time.RFC3339, req.EndTime)
	if err != nil {
		return nil, fmt.Errorf("invalid end_time: %w", err)
	}

	if endTime.Before(startTime) {
		return nil, fmt.Errorf("end_time must be after start_time")
	}

	sessionID := uuid.New()
	var offeringID *uuid.UUID
	if req.OfferingID != "" {
		oid, e := uuid.Parse(req.OfferingID)
		if e == nil {
			offeringID = &oid
		}
	}

	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO sessions (id, teacher_id, offering_id, title, description, session_type, start_time, end_time, max_participants, price, status)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'scheduled')`,
		sessionID, tuid, offeringID, req.Title, req.Description,
		req.SessionType, startTime, endTime, req.MaxStudents, req.Price,
	)
	if err != nil {
		return nil, fmt.Errorf("insert session: %w", err)
	}

	return s.GetSession(ctx, sessionID.String())
}

// GetSession retrieves a session by ID.
func (s *Service) GetSession(ctx context.Context, sessionID string) (*SessionResponse, error) {
	sid, err := uuid.Parse(sessionID)
	if err != nil {
		return nil, ErrSessionNotFound
	}

	var sr SessionResponse
	var startTime, endTime time.Time
	err = s.db.Pool.QueryRow(ctx,
		`SELECT s.id, s.teacher_id, u.first_name || ' ' || u.last_name,
		        s.title, COALESCE(s.description,''), s.session_type,
		        s.start_time, s.end_time, s.max_participants, s.price, s.status,
		        COALESCE(s.livekit_room_id,''), COALESCE(s.recording_url,'')
		 FROM sessions s
		 JOIN users u ON u.id = s.teacher_id
		 WHERE s.id = $1`, sid,
	).Scan(
		&sr.ID, &sr.TeacherID, &sr.TeacherName,
		&sr.Title, &sr.Description, &sr.SessionType,
		&startTime, &endTime, &sr.MaxStudents, &sr.Price, &sr.Status,
		&sr.RoomID, &sr.RecordingURL,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSessionNotFound
		}
		return nil, fmt.Errorf("get session: %w", err)
	}
	sr.StartTime = startTime.Format(time.RFC3339)
	sr.EndTime = endTime.Format(time.RFC3339)

	// fetch participants
	rows, err := s.db.Pool.Query(ctx,
		`SELECT u.id, u.first_name || ' ' || u.last_name, sp.attendance
		 FROM session_participants sp
		 JOIN users u ON u.id = sp.student_id
		 WHERE sp.session_id = $1`, sid,
	)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var p ParticipantBrief
			if err := rows.Scan(&p.UserID, &p.Name, &p.Attendance); err == nil {
				sr.Participants = append(sr.Participants, p)
			}
		}
	}

	return &sr, nil
}

// ListSessions lists sessions with optional filters.
func (s *Service) ListSessions(ctx context.Context, userID, role string, q ListSessionsQuery) ([]SessionResponse, int64, error) {
	uid, _ := uuid.Parse(userID)
	offset := (q.Page - 1) * q.Limit

	var countQuery, selectQuery string
	var args []interface{}

	switch role {
	case "teacher":
		countQuery = `SELECT COUNT(*) FROM sessions WHERE teacher_id = $1`
		selectQuery = `SELECT id FROM sessions WHERE teacher_id = $1 ORDER BY start_time DESC LIMIT $2 OFFSET $3`
		args = []interface{}{uid, q.Limit, offset}
	default: // student
		countQuery = `SELECT COUNT(*) FROM session_participants sp JOIN sessions s ON s.id = sp.session_id WHERE sp.student_id = $1`
		selectQuery = `SELECT s.id FROM sessions s JOIN session_participants sp ON sp.session_id = s.id WHERE sp.student_id = $1 ORDER BY s.start_time DESC LIMIT $2 OFFSET $3`
		args = []interface{}{uid, q.Limit, offset}
	}

	var total int64
	_ = s.db.Pool.QueryRow(ctx, countQuery, uid).Scan(&total)

	rows, err := s.db.Pool.Query(ctx, selectQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list sessions: %w", err)
	}
	defer rows.Close()

	var sessions []SessionResponse
	for rows.Next() {
		var sid string
		if err := rows.Scan(&sid); err != nil {
			continue
		}
		sess, err := s.GetSession(ctx, sid)
		if err == nil {
			sessions = append(sessions, *sess)
		}
	}

	return sessions, total, nil
}

// JoinSession creates a LiveKit room (if needed), adds participant, returns join token.
// If the session belongs to a series, enrollment and fee payment are verified.
func (s *Service) JoinSession(ctx context.Context, sessionID, userID, userName, role string) (*JoinSessionResponse, error) {
	sid, err := uuid.Parse(sessionID)
	if err != nil {
		return nil, ErrSessionNotFound
	}
	uid, _ := uuid.Parse(userID)

	// Get session including optional series_id
	var status, roomID string
	var teacherID uuid.UUID
	var seriesID *uuid.UUID
	err = s.db.Pool.QueryRow(ctx,
		`SELECT status, COALESCE(livekit_room_id,''), teacher_id, series_id FROM sessions WHERE id = $1`, sid,
	).Scan(&status, &roomID, &teacherID, &seriesID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSessionNotFound
		}
		return nil, err
	}

	if status != "scheduled" && status != "live" {
		return nil, ErrInvalidStatus
	}

	isTeacher := teacherID == uid

	// ── Series access control ─────────────────────────────────────
	// If session belongs to a series, enforce enrollment + fee checks
	if seriesID != nil {
		if !isTeacher {
			// Student must be enrolled with status 'accepted'
			var enrollStatus string
			err = s.db.Pool.QueryRow(ctx,
				`SELECT status::text FROM session_enrollments WHERE series_id = $1 AND student_id = $2`, *seriesID, uid,
			).Scan(&enrollStatus)
			if err != nil || enrollStatus != "accepted" {
				return nil, fmt.Errorf("not enrolled in this session series")
			}
		}

		// Both teacher and student: fee must be paid
		var feeStatus string
		err = s.db.Pool.QueryRow(ctx,
			`SELECT status::text FROM platform_fees WHERE series_id = $1 ORDER BY created_at DESC LIMIT 1`, *seriesID,
		).Scan(&feeStatus)
		if err != nil || feeStatus != "completed" {
			return nil, fmt.Errorf("platform fee not paid — cannot start session")
		}
	}

	// Create LiveKit room if not exists
	if roomID == "" {
		roomID = "session-" + sid.String()
		if s.livekit != nil {
			_, err = s.livekit.CreateRoom(ctx, roomID, lk.SessionTypeGroup, 30)
			if err != nil {
				return nil, fmt.Errorf("create livekit room: %w", err)
			}
		}
		// Update session with room_id and set to live
		_, err = s.db.Pool.Exec(ctx,
			`UPDATE sessions SET livekit_room_id = $1, status = 'live', actual_start = NOW() WHERE id = $2`, roomID, sid,
		)
		if err != nil {
			return nil, fmt.Errorf("update room: %w", err)
		}
	}

	// If student, add as participant
	if role == "student" {
		_, _ = s.db.Pool.Exec(ctx,
			`INSERT INTO session_participants (session_id, student_id, attendance)
			 SELECT $1, $2, 'present'
			 WHERE NOT EXISTS (SELECT 1 FROM session_participants WHERE session_id = $1 AND student_id = $2)`,
			sid, uid,
		)
	}

	// Generate LiveKit token
	var token string
	if s.livekit != nil {
		token, err = s.livekit.GenerateToken(roomID, userID, userName, isTeacher)
		if err != nil {
			return nil, fmt.Errorf("generate token: %w", err)
		}
	}

	return &JoinSessionResponse{
		RoomID:    roomID,
		Token:     token,
		URL:       "", // client-side LiveKit server URL from config
		IsTeacher: isTeacher,
	}, nil
}

// CancelSession cancels a scheduled session.
func (s *Service) CancelSession(ctx context.Context, sessionID, userID string, req CancelSessionRequest) error {
	sid, _ := uuid.Parse(sessionID)
	uid, _ := uuid.Parse(userID)

	var teacherID uuid.UUID
	var status string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status FROM sessions WHERE id = $1`, sid,
	).Scan(&teacherID, &status)
	if err != nil {
		return ErrSessionNotFound
	}

	if teacherID != uid {
		return ErrUnauthorized
	}
	if status != "scheduled" {
		return ErrInvalidStatus
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE sessions SET status = 'cancelled', cancelled_by = $1, cancellation_reason = $2 WHERE id = $3`,
		uid, req.Reason, sid,
	)
	return err
}

// RescheduleSession reschedules a session to new start/end times.
func (s *Service) RescheduleSession(ctx context.Context, sessionID, userID string, req RescheduleSessionRequest) (*SessionResponse, error) {
	sid, _ := uuid.Parse(sessionID)
	uid, _ := uuid.Parse(userID)

	var teacherID uuid.UUID
	var status string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status FROM sessions WHERE id = $1`, sid,
	).Scan(&teacherID, &status)
	if err != nil {
		return nil, ErrSessionNotFound
	}
	if teacherID != uid {
		return nil, ErrUnauthorized
	}
	if status != "scheduled" {
		return nil, ErrInvalidStatus
	}

	start, err := time.Parse(time.RFC3339, req.StartTime)
	if err != nil {
		return nil, fmt.Errorf("invalid start: %w", err)
	}
	end, err := time.Parse(time.RFC3339, req.EndTime)
	if err != nil {
		return nil, fmt.Errorf("invalid end: %w", err)
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE sessions SET start_time = $1, end_time = $2 WHERE id = $3`, start, end, sid,
	)
	if err != nil {
		return nil, fmt.Errorf("reschedule: %w", err)
	}

	return s.GetSession(ctx, sessionID)
}

// EndSession ends a live session and optionally cleans up the LiveKit room.
func (s *Service) EndSession(ctx context.Context, sessionID, userID string) error {
	sid, _ := uuid.Parse(sessionID)
	uid, _ := uuid.Parse(userID)

	var teacherID uuid.UUID
	var status, roomID string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status, COALESCE(livekit_room_id,'') FROM sessions WHERE id = $1`, sid,
	).Scan(&teacherID, &status, &roomID)
	if err != nil {
		return ErrSessionNotFound
	}
	if teacherID != uid {
		return ErrUnauthorized
	}
	if status != "live" {
		return ErrInvalidStatus
	}

	// Delete LiveKit room
	if roomID != "" && s.livekit != nil {
		_ = s.livekit.DeleteRoom(ctx, roomID)
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE sessions SET status = 'completed', actual_end = NOW() WHERE id = $1`, sid,
	)
	return err
}
