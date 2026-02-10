package sessionseries

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

// ═══════════════════════════════════════════════════════════════
// Errors
// ═══════════════════════════════════════════════════════════════

var (
	ErrSeriesNotFound     = errors.New("session series not found")
	ErrSessionNotFound    = errors.New("session not found")
	ErrEnrollmentNotFound = errors.New("enrollment not found")
	ErrFeeNotFound        = errors.New("platform fee not found")
	ErrNotAuthorized      = errors.New("not authorized")
	ErrSeriesFull         = errors.New("series has reached maximum students")
	ErrAlreadyInvited     = errors.New("student already invited to this series")
	ErrAlreadyAccepted    = errors.New("invitation already accepted")
	ErrAlreadyDeclined    = errors.New("invitation already declined")
	ErrFeeNotPaid         = errors.New("platform fee not paid — cannot join session")
	ErrNotEnrolled        = errors.New("not enrolled in this session")
	ErrInvalidStatus      = errors.New("invalid status for this action")
	ErrInvalidDates       = errors.New("end time must be after start time")
	ErrFeeAlreadyPaid     = errors.New("fee already paid")
)

// ═══════════════════════════════════════════════════════════════
// Service
// ═══════════════════════════════════════════════════════════════

type Service struct {
	db      *database.Postgres
	livekit *lk.Client
}

func NewService(db *database.Postgres, livekit *lk.Client) *Service {
	return &Service{db: db, livekit: livekit}
}

// ═══════════════════════════════════════════════════════════════
// Series CRUD
// ═══════════════════════════════════════════════════════════════

func (s *Service) CreateSeries(ctx context.Context, teacherID string, req CreateSeriesRequest) (*SeriesResponse, error) {
	tid, _ := uuid.Parse(teacherID)
	id := uuid.New()

	// Determine platform fee rate based on session type
	feeRate := GroupFeePerHour
	if req.SessionType == "individual" {
		feeRate = IndividualFeePerHour
	}

	// Default min_students
	minStudents := req.MinStudents
	if minStudents == 0 {
		if req.SessionType == "individual" {
			minStudents = 1
		} else {
			minStudents = 2
		}
	}

	// For individual sessions, max must be 1
	maxStudents := req.MaxStudents
	if req.SessionType == "individual" {
		maxStudents = 1
		minStudents = 1
	}

	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO session_series (id, teacher_id, offering_id, title, description,
		    session_type, duration_hours, min_students, max_students, total_sessions,
		    platform_fee_rate, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0,$10,'draft')`,
		id, tid, req.OfferingID, req.Title, req.Description,
		req.SessionType, req.DurationHours, minStudents, maxStudents,
		feeRate,
	)
	if err != nil {
		return nil, fmt.Errorf("create series: %w", err)
	}

	return s.GetSeries(ctx, id.String(), teacherID)
}

func (s *Service) GetSeries(ctx context.Context, seriesID string, callerID string) (*SeriesResponse, error) {
	sid, _ := uuid.Parse(seriesID)

	var sr SeriesResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT ss.id, ss.teacher_id, u.first_name || ' ' || u.last_name,
		        ss.offering_id, ss.title, COALESCE(ss.description,''),
		        ss.session_type, ss.duration_hours, ss.min_students, ss.max_students,
		        ss.total_sessions, ss.platform_fee_rate, ss.status::text,
		        ss.created_at, ss.updated_at
		 FROM session_series ss
		 JOIN users u ON u.id = ss.teacher_id
		 WHERE ss.id = $1`, sid,
	).Scan(
		&sr.ID, &sr.TeacherID, &sr.TeacherName,
		&sr.OfferingID, &sr.Title, &sr.Description,
		&sr.SessionType, &sr.DurationHours, &sr.MinStudents, &sr.MaxStudents,
		&sr.TotalSessions, &sr.PlatformFeeRate, &sr.Status,
		&sr.CreatedAt, &sr.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSeriesNotFound
		}
		return nil, fmt.Errorf("get series: %w", err)
	}

	// Fetch sessions in this series
	sessRows, err := s.db.Pool.Query(ctx,
		`SELECT id, session_number, start_time, end_time, status
		 FROM sessions WHERE series_id = $1 ORDER BY session_number`, sid)
	if err == nil {
		defer sessRows.Close()
		for sessRows.Next() {
			var sb SessionBrief
			if err := sessRows.Scan(&sb.ID, &sb.SessionNumber, &sb.StartTime, &sb.EndTime, &sb.Status); err == nil {
				sr.Sessions = append(sr.Sessions, sb)
			}
		}
	}
	if sr.Sessions == nil {
		sr.Sessions = []SessionBrief{}
	}

	// Fetch enrollments
	enrRows, err := s.db.Pool.Query(ctx,
		`SELECT se.id, se.student_id, u.first_name || ' ' || u.last_name,
		        se.status::text, se.platform_fee, se.fee_paid
		 FROM session_enrollments se
		 JOIN users u ON u.id = se.student_id
		 WHERE se.series_id = $1
		 ORDER BY se.invited_at`, sid)
	if err == nil {
		defer enrRows.Close()
		for enrRows.Next() {
			var eb EnrollmentBrief
			if err := enrRows.Scan(&eb.ID, &eb.StudentID, &eb.StudentName, &eb.Status, &eb.PlatformFee, &eb.FeePaid); err == nil {
				sr.Enrollments = append(sr.Enrollments, eb)
			}
		}
	}
	if sr.Enrollments == nil {
		sr.Enrollments = []EnrollmentBrief{}
	}

	// Count accepted enrollments
	for _, e := range sr.Enrollments {
		if e.Status == "accepted" {
			sr.EnrolledCount++
		}
	}

	return &sr, nil
}

func (s *Service) ListTeacherSeries(ctx context.Context, teacherID string, status string, page, limit int) ([]SeriesResponse, int64, error) {
	tid, _ := uuid.Parse(teacherID)
	offset := (page - 1) * limit

	countQ := `SELECT COUNT(*) FROM session_series WHERE teacher_id = $1`
	args := []interface{}{tid}
	argIdx := 2

	if status != "" {
		countQ += fmt.Sprintf(` AND status = $%d::series_status`, argIdx)
		args = append(args, status)
		argIdx++
	}

	var total int64
	_ = s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total)

	listQ := `SELECT id FROM session_series WHERE teacher_id = $1`
	listArgs := []interface{}{tid}
	if status != "" {
		listQ += ` AND status = $2::series_status`
		listArgs = append(listArgs, status)
	}
	listQ += fmt.Sprintf(` ORDER BY created_at DESC LIMIT %d OFFSET %d`, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("list series: %w", err)
	}
	defer rows.Close()

	var series []SeriesResponse
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			continue
		}
		sr, err := s.GetSeries(ctx, id, teacherID)
		if err == nil {
			series = append(series, *sr)
		}
	}
	if series == nil {
		series = []SeriesResponse{}
	}

	return series, total, nil
}

// ═══════════════════════════════════════════════════════════════
// Add Sessions to Series
// ═══════════════════════════════════════════════════════════════

func (s *Service) AddSessions(ctx context.Context, seriesID, teacherID string, req AddSessionsRequest) (*SeriesResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership
	var ownerID uuid.UUID
	var seriesStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status::text FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID, &seriesStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSeriesNotFound
		}
		return nil, err
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	// Get current session count
	var currentCount int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sessions WHERE series_id = $1`, sid,
	).Scan(&currentCount)

	// Get series info for session creation
	var durationHours float64
	var sessionType, title string
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT duration_hours, session_type, title FROM session_series WHERE id = $1`, sid,
	).Scan(&durationHours, &sessionType, &title)

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	for i, sess := range req.Sessions {
		startTime, err := time.Parse(time.RFC3339, sess.StartTime)
		if err != nil {
			return nil, fmt.Errorf("invalid start_time for session %d: %w", i+1, err)
		}
		endTime, err := time.Parse(time.RFC3339, sess.EndTime)
		if err != nil {
			return nil, fmt.Errorf("invalid end_time for session %d: %w", i+1, err)
		}
		if endTime.Before(startTime) || endTime.Equal(startTime) {
			return nil, ErrInvalidDates
		}

		sessionNum := currentCount + i + 1
		sessionTitle := fmt.Sprintf("%s - Session %d", title, sessionNum)

		maxParticipants := 1
		if sessionType == "group" {
			maxParticipants = 50 // will be enforced by series max_students
		}

		_, err = tx.Exec(ctx,
			`INSERT INTO sessions (id, teacher_id, series_id, session_number, title,
			    session_type, start_time, end_time, max_participants, price, status)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 0, 'scheduled')`,
			uuid.New(), tid, sid, sessionNum, sessionTitle,
			sessionType, startTime, endTime, maxParticipants,
		)
		if err != nil {
			return nil, fmt.Errorf("insert session %d: %w", sessionNum, err)
		}
	}

	// Update total_sessions count on the series
	_, err = tx.Exec(ctx,
		`UPDATE session_series SET total_sessions = (SELECT COUNT(*) FROM sessions WHERE series_id = $1),
		    status = 'active', updated_at = NOW()
		 WHERE id = $1`, sid,
	)
	if err != nil {
		return nil, fmt.Errorf("update series count: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	// Recalculate fees for existing enrollments (total_sessions changed)
	s.recalculateEnrollmentFees(ctx, sid)

	return s.GetSeries(ctx, seriesID, teacherID)
}

// ═══════════════════════════════════════════════════════════════
// Invitations
// ═══════════════════════════════════════════════════════════════

func (s *Service) InviteStudents(ctx context.Context, seriesID, teacherID string, req InviteStudentsRequest) ([]InvitationResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership & get series info
	var ownerID uuid.UUID
	var sessionType string
	var durationHours float64
	var totalSessions int
	var maxStudents int
	var feeRate float64
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, session_type, duration_hours, total_sessions, max_students, platform_fee_rate
		 FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID, &sessionType, &durationHours, &totalSessions, &maxStudents, &feeRate)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSeriesNotFound
		}
		return nil, err
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	// Check enrollment count
	var currentEnrolled int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND status != 'declined' AND status != 'removed'`,
		sid,
	).Scan(&currentEnrolled)

	if currentEnrolled+len(req.StudentIDs) > maxStudents {
		return nil, ErrSeriesFull
	}

	// Calculate fee
	fee, feePayer := calculatePlatformFee(sessionType, durationHours, totalSessions, feeRate)

	var results []InvitationResponse
	for _, studentIDStr := range req.StudentIDs {
		studentID, _ := uuid.Parse(studentIDStr)
		enrollID := uuid.New()

		_, err := s.db.Pool.Exec(ctx,
			`INSERT INTO session_enrollments (id, series_id, student_id, invited_by, status, platform_fee, fee_payer)
			 VALUES ($1, $2, $3, $4, 'invited', $5, $6)
			 ON CONFLICT (series_id, student_id) DO NOTHING`,
			enrollID, sid, studentID, tid, fee, feePayer,
		)
		if err != nil {
			continue // skip duplicates
		}

		// Fetch the created enrollment
		inv, err := s.getEnrollment(ctx, enrollID)
		if err == nil {
			results = append(results, *inv)
		}
	}

	if results == nil {
		results = []InvitationResponse{}
	}

	// TODO: Send push notifications to invited students

	return results, nil
}

func (s *Service) ListMyInvitations(ctx context.Context, userID string, status string, page, limit int) ([]InvitationResponse, int64, error) {
	uid, _ := uuid.Parse(userID)
	offset := (page - 1) * limit

	// Students see their own invitations
	// Parents see invitations for their children
	countQ := `SELECT COUNT(*) FROM session_enrollments se WHERE (se.student_id = $1 OR se.student_id IN (SELECT user_id FROM student_profiles WHERE parent_id = $1))`
	args := []interface{}{uid}

	if status != "" {
		countQ += ` AND se.status = $2::enrollment_status`
		args = append(args, status)
	}

	var total int64
	_ = s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total)

	listQ := `SELECT se.id FROM session_enrollments se
	          WHERE (se.student_id = $1 OR se.student_id IN (SELECT user_id FROM student_profiles WHERE parent_id = $1))`
	listArgs := []interface{}{uid}
	if status != "" {
		listQ += ` AND se.status = $2::enrollment_status`
		listArgs = append(listArgs, status)
	}
	listQ += fmt.Sprintf(` ORDER BY se.invited_at DESC LIMIT %d OFFSET %d`, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("list invitations: %w", err)
	}
	defer rows.Close()

	var invitations []InvitationResponse
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			continue
		}
		inv, err := s.getEnrollment(ctx, id)
		if err == nil {
			invitations = append(invitations, *inv)
		}
	}
	if invitations == nil {
		invitations = []InvitationResponse{}
	}
	return invitations, total, nil
}

func (s *Service) AcceptInvitation(ctx context.Context, enrollmentID, userID string) (*InvitationResponse, error) {
	eid, _ := uuid.Parse(enrollmentID)
	uid, _ := uuid.Parse(userID)

	// Verify this enrollment belongs to the user (or their child)
	var studentID uuid.UUID
	var currentStatus string
	var seriesID *uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT student_id, status::text, series_id FROM session_enrollments WHERE id = $1`, eid,
	).Scan(&studentID, &currentStatus, &seriesID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrEnrollmentNotFound
		}
		return nil, err
	}

	// Check authorization: user is the student, or user is the parent
	if studentID != uid {
		var isParent bool
		_ = s.db.Pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM student_profiles WHERE user_id = $1 AND parent_id = $2)`,
			studentID, uid,
		).Scan(&isParent)
		if !isParent {
			return nil, ErrNotAuthorized
		}
	}

	if currentStatus != "invited" {
		if currentStatus == "accepted" {
			return nil, ErrAlreadyAccepted
		}
		return nil, ErrInvalidStatus
	}

	// Accept the invitation
	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'accepted', accepted_at = $1 WHERE id = $2`,
		now, eid,
	)
	if err != nil {
		return nil, fmt.Errorf("accept invitation: %w", err)
	}

	// Create the platform fee record
	var platformFee float64
	var feePayer string
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT platform_fee, fee_payer FROM session_enrollments WHERE id = $1`, eid,
	).Scan(&platformFee, &feePayer)

	if platformFee > 0 {
		payerID := studentID // student pays for group
		if feePayer == "teacher" {
			// For individual sessions, teacher pays
			if seriesID != nil {
				_ = s.db.Pool.QueryRow(ctx,
					`SELECT teacher_id FROM session_series WHERE id = $1`, *seriesID,
				).Scan(&payerID)
			}
		}

		description := fmt.Sprintf("Platform fee for session enrollment %s", eid.String()[:8])
		_, err = s.db.Pool.Exec(ctx,
			`INSERT INTO platform_fees (id, enrollment_id, payer_id, amount, description, status)
			 VALUES ($1, $2, $3, $4, $5, 'pending')`,
			uuid.New(), eid, payerID, platformFee, description,
		)
		if err != nil {
			return nil, fmt.Errorf("create fee: %w", err)
		}
	}

	return s.getEnrollment(ctx, eid)
}

func (s *Service) DeclineInvitation(ctx context.Context, enrollmentID, userID string) error {
	eid, _ := uuid.Parse(enrollmentID)
	uid, _ := uuid.Parse(userID)

	var studentID uuid.UUID
	var currentStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT student_id, status::text FROM session_enrollments WHERE id = $1`, eid,
	).Scan(&studentID, &currentStatus)
	if err != nil {
		return ErrEnrollmentNotFound
	}

	// Check authorization
	if studentID != uid {
		var isParent bool
		_ = s.db.Pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM student_profiles WHERE user_id = $1 AND parent_id = $2)`,
			studentID, uid,
		).Scan(&isParent)
		if !isParent {
			return ErrNotAuthorized
		}
	}

	if currentStatus != "invited" {
		return ErrInvalidStatus
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'declined' WHERE id = $1`, eid,
	)
	return err
}

// ═══════════════════════════════════════════════════════════════
// Platform Fees
// ═══════════════════════════════════════════════════════════════

func (s *Service) ListPendingFees(ctx context.Context, userID string) ([]PlatformFeeResponse, error) {
	uid, _ := uuid.Parse(userID)

	rows, err := s.db.Pool.Query(ctx,
		`SELECT pf.id, pf.enrollment_id, pf.payer_id, u.first_name || ' ' || u.last_name,
		        pf.amount, COALESCE(pf.description,''), pf.status::text, pf.provider_ref,
		        pf.created_at, pf.paid_at
		 FROM platform_fees pf
		 JOIN users u ON u.id = pf.payer_id
		 WHERE pf.payer_id = $1 AND pf.status = 'pending'
		 ORDER BY pf.created_at DESC`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("list fees: %w", err)
	}
	defer rows.Close()

	var fees []PlatformFeeResponse
	for rows.Next() {
		var f PlatformFeeResponse
		if err := rows.Scan(
			&f.ID, &f.EnrollmentID, &f.PayerID, &f.PayerName,
			&f.Amount, &f.Description, &f.Status, &f.ProviderRef,
			&f.CreatedAt, &f.PaidAt,
		); err != nil {
			continue
		}
		fees = append(fees, f)
	}
	if fees == nil {
		fees = []PlatformFeeResponse{}
	}
	return fees, nil
}

func (s *Service) ConfirmFeePayment(ctx context.Context, feeID, userID string, req ConfirmFeePaymentRequest) (*PlatformFeeResponse, error) {
	fid, _ := uuid.Parse(feeID)
	uid, _ := uuid.Parse(userID)

	// Verify ownership
	var dbPayerID uuid.UUID
	var dbStatus string
	var enrollmentID uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT payer_id, status::text, enrollment_id FROM platform_fees WHERE id = $1`, fid,
	).Scan(&dbPayerID, &dbStatus, &enrollmentID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrFeeNotFound
		}
		return nil, err
	}
	if dbPayerID != uid {
		return nil, ErrNotAuthorized
	}
	if dbStatus != "pending" {
		return nil, ErrFeeAlreadyPaid
	}

	now := time.Now()

	// Update fee status
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE platform_fees SET status = 'completed', provider_ref = $1, paid_at = $2 WHERE id = $3`,
		req.ProviderRef, now, fid,
	)
	if err != nil {
		return nil, fmt.Errorf("confirm fee: %w", err)
	}

	// Mark enrollment as fee_paid
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET fee_paid = true, fee_paid_at = $1 WHERE id = $2`,
		now, enrollmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("update enrollment: %w", err)
	}

	// Fetch and return
	var f PlatformFeeResponse
	err = s.db.Pool.QueryRow(ctx,
		`SELECT pf.id, pf.enrollment_id, pf.payer_id, u.first_name || ' ' || u.last_name,
		        pf.amount, COALESCE(pf.description,''), pf.status::text, pf.provider_ref,
		        pf.created_at, pf.paid_at
		 FROM platform_fees pf
		 JOIN users u ON u.id = pf.payer_id
		 WHERE pf.id = $1`, fid,
	).Scan(
		&f.ID, &f.EnrollmentID, &f.PayerID, &f.PayerName,
		&f.Amount, &f.Description, &f.Status, &f.ProviderRef,
		&f.CreatedAt, &f.PaidAt,
	)
	if err != nil {
		return nil, fmt.Errorf("fetch fee: %w", err)
	}
	return &f, nil
}

// ═══════════════════════════════════════════════════════════════
// Join Session (Access Control)
// ═══════════════════════════════════════════════════════════════

func (s *Service) JoinSession(ctx context.Context, sessionID, userID, userName, role string) (*JoinResponse, error) {
	sessID, _ := uuid.Parse(sessionID)
	uid, _ := uuid.Parse(userID)

	// Get session info
	var teacherID uuid.UUID
	var seriesID *uuid.UUID
	var status, roomID, sessionType string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, series_id, status, COALESCE(livekit_room_id,''), session_type
		 FROM sessions WHERE id = $1`, sessID,
	).Scan(&teacherID, &seriesID, &status, &roomID, &sessionType)
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

	// If student, check enrollment and payment
	if !isTeacher {
		allowed, reason := s.checkAccess(ctx, sessID, seriesID, uid, sessionType)
		if !allowed {
			switch reason {
			case "not_enrolled":
				return nil, ErrNotEnrolled
			case "fee_not_paid":
				return nil, ErrFeeNotPaid
			default:
				return nil, ErrNotAuthorized
			}
		}

		// Add as participant
		_, _ = s.db.Pool.Exec(ctx,
			`INSERT INTO session_participants (session_id, student_id, attendance)
			 SELECT $1, $2, 'present'
			 WHERE NOT EXISTS (SELECT 1 FROM session_participants WHERE session_id = $1 AND student_id = $2)`,
			sessID, uid,
		)
	}

	// Create LiveKit room if needed
	if roomID == "" {
		roomID = "session-" + sessID.String()
		if s.livekit != nil {
			_, err = s.livekit.CreateRoom(ctx, roomID, lk.SessionTypeGroup, 30)
			if err != nil {
				return nil, fmt.Errorf("create livekit room: %w", err)
			}
		}
		_, err = s.db.Pool.Exec(ctx,
			`UPDATE sessions SET livekit_room_id = $1, status = 'live', actual_start = NOW() WHERE id = $2`,
			roomID, sessID,
		)
		if err != nil {
			return nil, fmt.Errorf("update room: %w", err)
		}
	}

	// Generate LiveKit token
	var token string
	if s.livekit != nil {
		token, err = s.livekit.GenerateToken(roomID, userID, userName, isTeacher)
		if err != nil {
			return nil, fmt.Errorf("generate token: %w", err)
		}
	}

	return &JoinResponse{
		RoomID:    roomID,
		Token:     token,
		IsTeacher: isTeacher,
	}, nil
}

// checkAccess verifies if a student can join based on enrollment and fee payment
func (s *Service) checkAccess(ctx context.Context, sessionID uuid.UUID, seriesID *uuid.UUID, studentID uuid.UUID, sessionType string) (bool, string) {
	// Check enrollment through series
	if seriesID != nil {
		var feePaid bool
		var enrollStatus string
		err := s.db.Pool.QueryRow(ctx,
			`SELECT status::text, fee_paid FROM session_enrollments
			 WHERE series_id = $1 AND student_id = $2`, *seriesID, studentID,
		).Scan(&enrollStatus, &feePaid)
		if err != nil {
			return false, "not_enrolled"
		}
		if enrollStatus != "accepted" {
			return false, "not_enrolled"
		}
		if !feePaid {
			return false, "fee_not_paid"
		}
		return true, ""
	}

	// Check direct session enrollment
	var feePaid bool
	var enrollStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT status::text, fee_paid FROM session_enrollments
		 WHERE session_id = $1 AND student_id = $2`, sessionID, studentID,
	).Scan(&enrollStatus, &feePaid)
	if err != nil {
		return false, "not_enrolled"
	}
	if enrollStatus != "accepted" {
		return false, "not_enrolled"
	}
	if !feePaid {
		return false, "fee_not_paid"
	}
	return true, ""
}

// ═══════════════════════════════════════════════════════════════
// Teacher: Add Student to Existing Series
// ═══════════════════════════════════════════════════════════════

func (s *Service) AddStudentToSeries(ctx context.Context, seriesID, teacherID, studentID string) (*InvitationResponse, error) {
	// This is essentially an invite + auto-accept
	invitations, err := s.InviteStudents(ctx, seriesID, teacherID, InviteStudentsRequest{
		StudentIDs: []string{studentID},
	})
	if err != nil {
		return nil, err
	}
	if len(invitations) == 0 {
		return nil, ErrAlreadyInvited
	}
	return &invitations[0], nil
}

func (s *Service) RemoveStudentFromSeries(ctx context.Context, seriesID, teacherID, studentID string) error {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)
	stid, _ := uuid.Parse(studentID)

	// Verify ownership
	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID)
	if err != nil {
		return ErrSeriesNotFound
	}
	if ownerID != tid {
		return ErrNotAuthorized
	}

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'removed' WHERE series_id = $1 AND student_id = $2`,
		sid, stid,
	)
	if err != nil {
		return fmt.Errorf("remove student: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrEnrollmentNotFound
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

func calculatePlatformFee(sessionType string, durationHours float64, totalSessions int, feeRate float64) (float64, string) {
	fee := feeRate * durationHours * float64(totalSessions)
	feePayer := "student"
	if sessionType == "individual" {
		feePayer = "teacher"
	}
	return fee, feePayer
}

func (s *Service) recalculateEnrollmentFees(ctx context.Context, seriesID uuid.UUID) {
	var durationHours float64
	var totalSessions int
	var feeRate float64
	var sessionType string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT duration_hours, total_sessions, platform_fee_rate, session_type
		 FROM session_series WHERE id = $1`, seriesID,
	).Scan(&durationHours, &totalSessions, &feeRate, &sessionType)
	if err != nil {
		return
	}

	newFee, _ := calculatePlatformFee(sessionType, durationHours, totalSessions, feeRate)

	// Only update enrollments where fee hasn't been paid yet
	_, _ = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET platform_fee = $1
		 WHERE series_id = $2 AND fee_paid = false`, newFee, seriesID,
	)

	// Also update any pending platform_fees records
	_, _ = s.db.Pool.Exec(ctx,
		`UPDATE platform_fees SET amount = $1
		 WHERE enrollment_id IN (SELECT id FROM session_enrollments WHERE series_id = $2 AND fee_paid = false)
		   AND status = 'pending'`, newFee, seriesID,
	)
}

func (s *Service) getEnrollment(ctx context.Context, enrollID uuid.UUID) (*InvitationResponse, error) {
	var inv InvitationResponse
	var seriesTitle *string

	err := s.db.Pool.QueryRow(ctx,
		`SELECT se.id, se.series_id, se.session_id,
		        ss.title, t.first_name || ' ' || t.last_name,
		        se.student_id, u.first_name || ' ' || u.last_name,
		        se.status::text, ss.session_type,
		        se.platform_fee, se.fee_paid, COALESCE(se.fee_payer, 'student'),
		        se.invited_at, se.accepted_at
		 FROM session_enrollments se
		 LEFT JOIN session_series ss ON ss.id = se.series_id
		 LEFT JOIN users t ON t.id = ss.teacher_id
		 JOIN users u ON u.id = se.student_id
		 WHERE se.id = $1`, enrollID,
	).Scan(
		&inv.ID, &inv.SeriesID, &inv.SessionID,
		&seriesTitle, &inv.TeacherName,
		&inv.StudentID, &inv.StudentName,
		&inv.Status, &inv.SessionType,
		&inv.PlatformFee, &inv.FeePaid, &inv.FeePayer,
		&inv.InvitedAt, &inv.AcceptedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrEnrollmentNotFound
		}
		return nil, fmt.Errorf("get enrollment: %w", err)
	}
	if seriesTitle != nil {
		inv.SeriesTitle = *seriesTitle
	}
	return &inv, nil
}
