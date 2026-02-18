package sessionseries

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"educonnect/internal/wallet"
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
	ErrAlreadyEnrolled    = errors.New("student already enrolled in this series")
	ErrAlreadyRequested   = errors.New("already requested to join this series")
	ErrInvalidStatus      = errors.New("invalid status for this action")
	ErrInvalidDates       = errors.New("end time must be after start time")
	ErrFeeNotPaid         = errors.New("platform fee not paid — cannot start session")
	ErrNotEnrolled        = errors.New("not enrolled in this session")
	ErrFeeAlreadyPaid     = errors.New("fee already paid")
	ErrNoEnrollments      = errors.New("no enrolled students — cannot finalize")
	ErrAlreadyFinalized   = errors.New("series already finalized")
	ErrNotFinalized       = errors.New("series not finalized — cannot pay yet")
	ErrNoSessions         = errors.New("no sessions added to series")
)

// ═══════════════════════════════════════════════════════════════
// Service
// ═══════════════════════════════════════════════════════════════

type Service struct {
	db      *database.Postgres
	livekit *lk.Client
	wallet  *wallet.Service
}

func NewService(db *database.Postgres, livekit *lk.Client, walletSvc *wallet.Service) *Service {
	return &Service{db: db, livekit: livekit, wallet: walletSvc}
}

// ═══════════════════════════════════════════════════════════════
// Series CRUD
// ═══════════════════════════════════════════════════════════════

func (s *Service) CreateSeries(ctx context.Context, teacherID string, req CreateSeriesRequest) (*SeriesResponse, error) {
	tid, _ := uuid.Parse(teacherID)
	id := uuid.New()

	// Default min_students
	minStudents := req.MinStudents
	if minStudents == 0 {
		if req.SessionType == "one_on_one" {
			minStudents = 1
		} else {
			minStudents = 2
		}
	}

	// For individual sessions, max must be 1
	maxStudents := req.MaxStudents
	if req.SessionType == "one_on_one" {
		maxStudents = 1
		minStudents = 1
	}

	// Resolve level code to UUID if provided as code (e.g., "3AM")
	var levelID *uuid.UUID
	if req.LevelID != nil && *req.LevelID != "" {
		// Check if it's already a UUID
		if parsed, err := uuid.Parse(*req.LevelID); err == nil {
			levelID = &parsed
		} else {
			// It's a code, resolve to UUID
			pattern := s.levelCodeToPattern(*req.LevelID)
			var resolvedID uuid.UUID
			err := s.db.Pool.QueryRow(ctx,
				`SELECT id FROM levels WHERE LOWER(name) LIKE LOWER($1) LIMIT 1`, pattern,
			).Scan(&resolvedID)
			if err == nil {
				levelID = &resolvedID
			}
		}
	}

	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO session_series (id, teacher_id, offering_id, level_id, subject_id, title, description,
		    session_type, duration_hours, min_students, max_students, price_per_hour, status)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'draft')`,
		id, tid, req.OfferingID, levelID, req.SubjectID, req.Title, req.Description,
		req.SessionType, req.DurationHours, minStudents, maxStudents, req.PricePerHour,
	)
	if err != nil {
		return nil, fmt.Errorf("create series: %w", err)
	}

	return s.GetSeries(ctx, id.String(), teacherID)
}

func (s *Service) GetSeries(ctx context.Context, seriesID string, callerID string) (*SeriesResponse, error) {
	sid, err := uuid.Parse(seriesID)
	if err != nil {
		return nil, ErrSeriesNotFound
	}

	var sr SeriesResponse
	var finalizedAt *time.Time
	err = s.db.Pool.QueryRow(ctx,
		`SELECT ss.id, ss.teacher_id, u.first_name || ' ' || u.last_name,
		        ss.offering_id, ss.level_id, ss.subject_id, ss.title, COALESCE(ss.description,''),
		        ss.session_type::text, ss.duration_hours, ss.min_students, ss.max_students,
		        ss.price_per_hour, ss.status::text, ss.is_finalized, ss.finalized_at,
		        ss.created_at, ss.updated_at
		 FROM session_series ss
		 JOIN users u ON u.id = ss.teacher_id
		 WHERE ss.id = $1`, sid,
	).Scan(
		&sr.ID, &sr.TeacherID, &sr.TeacherName,
		&sr.OfferingID, &sr.LevelID, &sr.SubjectID, &sr.Title, &sr.Description,
		&sr.SessionType, &sr.DurationHours, &sr.MinStudents, &sr.MaxStudents,
		&sr.PricePerHour, &sr.Status, &sr.IsFinalized, &finalizedAt,
		&sr.CreatedAt, &sr.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSeriesNotFound
		}
		return nil, fmt.Errorf("get series: %w", err)
	}
	sr.FinalizedAt = finalizedAt

	// Fetch subject/level names - try direct columns first, then offering
	if sr.SubjectID != nil || sr.LevelID != nil {
		if sr.SubjectID != nil {
			var subjectName string
			_ = s.db.Pool.QueryRow(ctx, `SELECT name_fr FROM subjects WHERE id = $1`, *sr.SubjectID).Scan(&subjectName)
			sr.SubjectName = subjectName
		}
		if sr.LevelID != nil {
			var levelName string
			_ = s.db.Pool.QueryRow(ctx, `SELECT name FROM levels WHERE id = $1`, *sr.LevelID).Scan(&levelName)
			sr.LevelName = levelName
		}
	} else if sr.OfferingID != nil {
		var subjectName, levelName string
		_ = s.db.Pool.QueryRow(ctx,
			`SELECT COALESCE(s.name_fr, ''), COALESCE(l.name, '')
			 FROM offerings o
			 LEFT JOIN subjects s ON s.id = o.subject_id
			 LEFT JOIN levels l ON l.id = o.level_id
			 WHERE o.id = $1`, *sr.OfferingID,
		).Scan(&subjectName, &levelName)
		sr.SubjectName = subjectName
		sr.LevelName = levelName
	}

	// Count sessions
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sessions WHERE series_id = $1`, sid,
	).Scan(&sr.TotalSessions)

	// Fetch sessions in this series
	sessRows, err := s.db.Pool.Query(ctx,
		`SELECT id, session_number, title, start_time, end_time, status::text
		 FROM sessions WHERE series_id = $1 ORDER BY session_number`, sid)
	if err == nil {
		defer sessRows.Close()
		for sessRows.Next() {
			var sb SessionBrief
			if err := sessRows.Scan(&sb.ID, &sb.SessionNumber, &sb.Title, &sb.StartTime, &sb.EndTime, &sb.Status); err == nil {
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
		        se.initiated_by, se.status::text, se.created_at, se.accepted_at
		 FROM session_enrollments se
		 JOIN users u ON u.id = se.student_id
		 WHERE se.series_id = $1
		 ORDER BY se.created_at`, sid)
	if err == nil {
		defer enrRows.Close()
		for enrRows.Next() {
			var eb EnrollmentBrief
			if err := enrRows.Scan(&eb.ID, &eb.StudentID, &eb.StudentName, &eb.InitiatedBy, &eb.Status, &eb.CreatedAt, &eb.AcceptedAt); err == nil {
				sr.Enrollments = append(sr.Enrollments, eb)
				if eb.Status == "accepted" {
					sr.EnrolledCount++
				} else if eb.Status == "invited" || eb.Status == "requested" {
					sr.PendingCount++
				}
			}
		}
	}
	if sr.Enrollments == nil {
		sr.Enrollments = []EnrollmentBrief{}
	}

	// Star cost per enrollment
	if sr.SessionType == "one_on_one" {
		sr.StarCost = PrivateStarCost
	} else {
		sr.StarCost = GroupStarCost
	}

	return &sr, nil
}

func (s *Service) ListTeacherSeries(ctx context.Context, teacherID string, status string, page, limit int) ([]SeriesResponse, int64, error) {
	tid, _ := uuid.Parse(teacherID)
	offset := (page - 1) * limit

	countQ := `SELECT COUNT(*) FROM session_series WHERE teacher_id = $1`
	args := []interface{}{tid}

	if status != "" {
		countQ += ` AND status = $2::series_status`
		args = append(args, status)
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

// BrowseAvailableSeries returns public series available for enrollment (active or finalized)
// Also returns current user's enrollment status for each series
func (s *Service) BrowseAvailableSeries(ctx context.Context, currentUserID, subjectID, levelID, sessionType string, page, limit int) ([]SeriesResponse, int64, error) {
	offset := (page - 1) * limit

	// Resolve level code to UUID if needed (e.g., "3AM" -> UUID)
	resolvedLevelID := levelID
	if levelID != "" {
		// Check if it's not a valid UUID (i.e., it's a code like "3AM")
		if _, err := uuid.Parse(levelID); err != nil {
			var levelUUID string
			// Map common level codes to search patterns
			// e.g., "3AM" -> "3ème Année Moyenne", "1AP" -> "1ère Année Primaire"
			searchPattern := s.levelCodeToPattern(levelID)
			err := s.db.Pool.QueryRow(ctx,
				`SELECT id::text FROM levels WHERE UPPER(name) LIKE UPPER($1) LIMIT 1`,
				searchPattern,
			).Scan(&levelUUID)
			if err == nil {
				resolvedLevelID = levelUUID
			}
		}
	}

	// Build query for series available for enrollment (active or finalized, not draft/completed/cancelled)
	// Filter uses both direct columns (ss.level_id, ss.subject_id) and offering columns (o.level_id, o.subject_id)
	baseWhere := `WHERE ss.status IN ('active', 'finalized')`
	args := []interface{}{}
	argIdx := 1

	if subjectID != "" {
		baseWhere += fmt.Sprintf(` AND (ss.subject_id = $%d OR o.subject_id = $%d)`, argIdx, argIdx)
		args = append(args, subjectID)
		argIdx++
	}
	if resolvedLevelID != "" {
		baseWhere += fmt.Sprintf(` AND (ss.level_id = $%d OR o.level_id = $%d)`, argIdx, argIdx)
		args = append(args, resolvedLevelID)
		argIdx++
	}
	if sessionType != "" {
		baseWhere += fmt.Sprintf(` AND ss.session_type = $%d`, argIdx)
		args = append(args, sessionType)
		argIdx++
	}

	countQ := `SELECT COUNT(*) FROM session_series ss 
		LEFT JOIN offerings o ON o.id = ss.offering_id ` + baseWhere
	var total int64
	_ = s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total)

	listQ := fmt.Sprintf(`SELECT ss.id, ss.teacher_id FROM session_series ss
		LEFT JOIN offerings o ON o.id = ss.offering_id
		%s
		ORDER BY ss.created_at DESC
		LIMIT %d OFFSET %d`, baseWhere, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("browse series: %w", err)
	}
	defer rows.Close()

	var series []SeriesResponse
	for rows.Next() {
		var id, teacherID string
		if err := rows.Scan(&id, &teacherID); err != nil {
			continue
		}
		sr, err := s.GetSeries(ctx, id, teacherID)
		if err == nil {
			// Check if current user has an enrollment in this series
			if currentUserID != "" {
				sr.CurrentUserStatus = s.getUserEnrollmentStatus(ctx, id, currentUserID)
			}
			series = append(series, *sr)
		}
	}
	if series == nil {
		series = []SeriesResponse{}
	}

	return series, total, nil
}

// levelCodeToPattern converts a level code to a search pattern for the database
// e.g., "3AM" -> "%3%Moyenne%", "1AP" -> "%1%Primaire%", "2AS" -> "%2%Secondaire%"
func (s *Service) levelCodeToPattern(code string) string {
	code = strings.ToUpper(code)

	// Extract number and suffix
	if len(code) < 2 {
		return "%" + code + "%"
	}

	// Common patterns: 1AP, 2AM, 3AS, L1, M1, BEM, BAC
	switch {
	case strings.HasSuffix(code, "AP"): // Primaire
		num := strings.TrimSuffix(code, "AP")
		return "%" + num + "%Primaire%"
	case strings.HasSuffix(code, "AM"): // Moyenne
		num := strings.TrimSuffix(code, "AM")
		return "%" + num + "%Moyenne%"
	case strings.HasSuffix(code, "AS"): // Secondaire - DB uses "1AS —" format
		return code + "%"
	case strings.HasPrefix(code, "L"): // Licence
		return "%Licence " + strings.TrimPrefix(code, "L") + "%"
	case strings.HasPrefix(code, "M"): // Master
		return "%Master " + strings.TrimPrefix(code, "M") + "%"
	case code == "BEM":
		return "%BEM%"
	case code == "BAC":
		return "%BAC%"
	default:
		return "%" + code + "%"
	}
}

// getUserEnrollmentStatus returns the enrollment status for a user in a series
func (s *Service) getUserEnrollmentStatus(ctx context.Context, seriesID, userID string) string {
	var status string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT status::text FROM session_enrollments WHERE series_id = $1 AND student_id = $2`,
		seriesID, userID,
	).Scan(&status)
	if err != nil {
		return "" // Not enrolled
	}
	return status
}

// ═══════════════════════════════════════════════════════════════
// Add Sessions to Series
// ═══════════════════════════════════════════════════════════════

func (s *Service) AddSessions(ctx context.Context, seriesID, teacherID string, req AddSessionsRequest) (*SeriesResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership
	var ownerID uuid.UUID
	var seriesStatus, title string
	var durationHours float64
	var sessionType string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status::text, title, duration_hours, session_type::text FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID, &seriesStatus, &title, &durationHours, &sessionType)
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
		// Calculate end time based on duration
		endTime := startTime.Add(time.Duration(durationHours * float64(time.Hour)))

		sessionNum := currentCount + i + 1
		sessionTitle := title
		if len(req.Sessions) > 1 || currentCount > 0 {
			sessionTitle = fmt.Sprintf("%s - Séance %d", title, sessionNum)
		}

		maxParticipants := 1
		if sessionType == "group" {
			maxParticipants = 50
		}

		_, err = tx.Exec(ctx,
			`INSERT INTO sessions (id, teacher_id, series_id, session_number, title,
			    session_type, start_time, end_time, max_participants, price, status)
			 VALUES ($1, $2, $3, $4, $5, $6::session_type, $7, $8, $9, 0, 'scheduled')`,
			uuid.New(), tid, sid, sessionNum, sessionTitle,
			sessionType, startTime, endTime, maxParticipants,
		)
		if err != nil {
			return nil, fmt.Errorf("insert session %d: %w", sessionNum, err)
		}
	}

	// Update series status to active if it was draft
	_, err = tx.Exec(ctx,
		`UPDATE session_series SET status = 'active', updated_at = NOW() WHERE id = $1 AND status = 'draft'`, sid,
	)
	if err != nil {
		return nil, fmt.Errorf("update series: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return s.GetSeries(ctx, seriesID, teacherID)
}

// ═══════════════════════════════════════════════════════════════
// Teacher Invites Students
// ═══════════════════════════════════════════════════════════════

func (s *Service) InviteStudents(ctx context.Context, seriesID, teacherID string, req InviteStudentsRequest) ([]EnrollmentResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership & get series info
	var ownerID uuid.UUID
	var maxStudents int
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, max_students FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID, &maxStudents)
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
		`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND status NOT IN ('declined', 'removed')`,
		sid,
	).Scan(&currentEnrolled)

	if currentEnrolled+len(req.StudentIDs) > maxStudents {
		return nil, ErrSeriesFull
	}

	var results []EnrollmentResponse
	now := time.Now()
	for _, studentIDStr := range req.StudentIDs {
		var studentID uuid.UUID

		// Try to parse as UUID first, otherwise look up by email
		parsedID, err := uuid.Parse(studentIDStr)
		if err != nil {
			// Not a UUID, try to find user by email
			err = s.db.Pool.QueryRow(ctx,
				`SELECT id FROM users WHERE email = $1 AND role IN ('student', 'parent')`, studentIDStr,
			).Scan(&studentID)
			if err != nil {
				continue // User not found, skip
			}
		} else {
			studentID = parsedID
		}

		enrollID := uuid.New()

		_, err = s.db.Pool.Exec(ctx,
			`INSERT INTO session_enrollments (id, series_id, student_id, initiated_by, status, invited_at)
			 VALUES ($1, $2, $3, 'teacher', 'invited', $4)
			 ON CONFLICT (series_id, student_id) DO NOTHING`,
			enrollID, sid, studentID, now,
		)
		if err != nil {
			continue // skip errors
		}

		// Fetch the created enrollment
		enr, err := s.getEnrollment(ctx, enrollID)
		if err == nil {
			results = append(results, *enr)
		}
	}

	if results == nil {
		results = []EnrollmentResponse{}
	}

	// TODO: Send push notifications to invited students

	return results, nil
}

// ═══════════════════════════════════════════════════════════════
// Student Requests to Join
// ═══════════════════════════════════════════════════════════════

func (s *Service) RequestToJoin(ctx context.Context, seriesID, studentID string) (*EnrollmentResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	stid, _ := uuid.Parse(studentID)

	// Check series exists and is not full
	var maxStudents int
	var seriesStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT max_students, status::text FROM session_series WHERE id = $1`, sid,
	).Scan(&maxStudents, &seriesStatus)
	if err != nil {
		return nil, ErrSeriesNotFound
	}

	if seriesStatus != "active" && seriesStatus != "draft" {
		return nil, ErrInvalidStatus
	}

	// Check if already enrolled/requested
	var existing int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND student_id = $2 AND status NOT IN ('declined', 'removed')`,
		sid, stid,
	).Scan(&existing)
	if existing > 0 {
		return nil, ErrAlreadyRequested
	}

	// Check capacity
	var currentEnrolled int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND status NOT IN ('declined', 'removed')`, sid,
	).Scan(&currentEnrolled)
	if currentEnrolled >= maxStudents {
		return nil, ErrSeriesFull
	}

	enrollID := uuid.New()
	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO session_enrollments (id, series_id, student_id, initiated_by, status, requested_at)
		 VALUES ($1, $2, $3, 'student', 'requested', $4)`,
		enrollID, sid, stid, now,
	)
	if err != nil {
		return nil, fmt.Errorf("request to join: %w", err)
	}

	// TODO: Send notification to teacher

	return s.getEnrollment(ctx, enrollID)
}

// ═══════════════════════════════════════════════════════════════
// Accept/Decline Enrollments
// ═══════════════════════════════════════════════════════════════

// Student accepts teacher's invitation — deducts 1 star from teacher wallet.
func (s *Service) AcceptInvitation(ctx context.Context, enrollmentID, studentID string) (*EnrollmentResponse, error) {
	eid, _ := uuid.Parse(enrollmentID)
	stid, _ := uuid.Parse(studentID)

	// Verify ownership
	var dbStudentID uuid.UUID
	var currentStatus, initiatedBy string
	var seriesID uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT student_id, series_id, status::text, initiated_by FROM session_enrollments WHERE id = $1`, eid,
	).Scan(&dbStudentID, &seriesID, &currentStatus, &initiatedBy)
	if err != nil {
		return nil, ErrEnrollmentNotFound
	}

	if dbStudentID != stid {
		// Check if parent
		var isParent bool
		_ = s.db.Pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM student_profiles WHERE user_id = $1 AND parent_id = $2)`,
			dbStudentID, stid,
		).Scan(&isParent)
		if !isParent {
			return nil, ErrNotAuthorized
		}
	}

	if initiatedBy != "teacher" || currentStatus != "invited" {
		return nil, ErrInvalidStatus
	}

	// Get series info for star deduction
	var teacherID uuid.UUID
	var sessionType, seriesTitle string
	err = s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, session_type::text, title FROM session_series WHERE id = $1`, seriesID,
	).Scan(&teacherID, &sessionType, &seriesTitle)
	if err != nil {
		return nil, ErrSeriesNotFound
	}

	// Get student name for transaction description
	var studentName string
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, dbStudentID,
	).Scan(&studentName)

	// ★ Deduct star from teacher wallet (ACID)
	if s.wallet != nil {
		_, err = s.wallet.DeductStar(ctx, teacherID.String(), sessionType, eid, seriesID, studentName, seriesTitle)
		if err != nil {
			return nil, err
		}
	}

	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'accepted', accepted_at = $1 WHERE id = $2`,
		now, eid,
	)
	if err != nil {
		return nil, fmt.Errorf("accept invitation: %w", err)
	}

	return s.getEnrollment(ctx, eid)
}

// Student declines teacher's invitation
func (s *Service) DeclineInvitation(ctx context.Context, enrollmentID, studentID string) error {
	eid, _ := uuid.Parse(enrollmentID)
	stid, _ := uuid.Parse(studentID)

	var dbStudentID uuid.UUID
	var currentStatus, initiatedBy string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT student_id, status::text, initiated_by FROM session_enrollments WHERE id = $1`, eid,
	).Scan(&dbStudentID, &currentStatus, &initiatedBy)
	if err != nil {
		return ErrEnrollmentNotFound
	}

	if dbStudentID != stid {
		return ErrNotAuthorized
	}

	if initiatedBy != "teacher" || currentStatus != "invited" {
		return ErrInvalidStatus
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'declined' WHERE id = $1`, eid,
	)
	return err
}

// Teacher accepts student's request — deducts 1 star from teacher wallet.
func (s *Service) AcceptRequest(ctx context.Context, seriesID, enrollmentID, teacherID string) (*EnrollmentResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	eid, _ := uuid.Parse(enrollmentID)
	tid, _ := uuid.Parse(teacherID)

	// Verify teacher owns series and get session type
	var ownerID uuid.UUID
	var sessionType string
	var seriesTitle string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, session_type::text, title FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID, &sessionType, &seriesTitle)
	if err != nil {
		return nil, ErrSeriesNotFound
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	// Verify enrollment exists and is a request
	var currentStatus, initiatedBy string
	var enrollSeriesID uuid.UUID
	var studentID uuid.UUID
	err = s.db.Pool.QueryRow(ctx,
		`SELECT series_id, student_id, status::text, initiated_by FROM session_enrollments WHERE id = $1`, eid,
	).Scan(&enrollSeriesID, &studentID, &currentStatus, &initiatedBy)
	if err != nil {
		return nil, ErrEnrollmentNotFound
	}
	if enrollSeriesID != sid {
		return nil, ErrNotAuthorized
	}
	if initiatedBy != "student" || currentStatus != "requested" {
		return nil, ErrInvalidStatus
	}

	// Get student name for transaction description
	var studentName string
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, studentID,
	).Scan(&studentName)

	// ★ Deduct star from teacher wallet (ACID)
	if s.wallet != nil {
		_, err = s.wallet.DeductStar(ctx, teacherID, sessionType, eid, sid, studentName, seriesTitle)
		if err != nil {
			return nil, err // ErrInsufficientBalance propagates with 402 status
		}
	}

	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'accepted', accepted_at = $1 WHERE id = $2`,
		now, eid,
	)
	if err != nil {
		return nil, fmt.Errorf("accept request: %w", err)
	}

	return s.getEnrollment(ctx, eid)
}

// Teacher declines student's request
func (s *Service) DeclineRequest(ctx context.Context, seriesID, enrollmentID, teacherID string) error {
	sid, _ := uuid.Parse(seriesID)
	eid, _ := uuid.Parse(enrollmentID)
	tid, _ := uuid.Parse(teacherID)

	// Verify teacher owns series
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

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE session_enrollments SET status = 'declined' WHERE id = $1 AND series_id = $2`, eid, sid,
	)
	return err
}

// Teacher removes student from series — refunds star if before first session.
func (s *Service) RemoveStudent(ctx context.Context, seriesID, studentID, teacherID string) error {
	sid, _ := uuid.Parse(seriesID)
	stid, _ := uuid.Parse(studentID)
	tid, _ := uuid.Parse(teacherID)

	// Verify teacher owns series
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

	// Get enrollment ID before updating
	var enrollmentID uuid.UUID
	err = s.db.Pool.QueryRow(ctx,
		`SELECT id FROM session_enrollments WHERE series_id = $1 AND student_id = $2 AND status = 'accepted'`,
		sid, stid,
	).Scan(&enrollmentID)
	wasAccepted := err == nil

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

	// ★ Refund star if enrollment was accepted (idempotent, checks 1st session internally)
	if wasAccepted && s.wallet != nil {
		_ = s.wallet.RefundStar(ctx, teacherID, enrollmentID)
		// Refund is best-effort; if first session started, no refund — that's fine
	}

	return nil
}

// ═══════════════════════════════════════════════════════════════
// List Enrollments
// ═══════════════════════════════════════════════════════════════

// List invitations for a student (teacher-initiated)
func (s *Service) ListMyInvitations(ctx context.Context, studentID string, status string, page, limit int) ([]EnrollmentResponse, int64, error) {
	uid, _ := uuid.Parse(studentID)
	offset := (page - 1) * limit

	countQ := `SELECT COUNT(*) FROM session_enrollments se 
	           WHERE (se.student_id = $1 OR se.student_id IN (SELECT user_id FROM student_profiles WHERE parent_id = $1))
	           AND se.initiated_by = 'teacher'`
	args := []interface{}{uid}

	if status != "" {
		countQ += ` AND se.status = $2::enrollment_status`
		args = append(args, status)
	}

	var total int64
	_ = s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total)

	listQ := `SELECT se.id FROM session_enrollments se
	          WHERE (se.student_id = $1 OR se.student_id IN (SELECT user_id FROM student_profiles WHERE parent_id = $1))
	          AND se.initiated_by = 'teacher'`
	listArgs := []interface{}{uid}
	if status != "" {
		listQ += ` AND se.status = $2::enrollment_status`
		listArgs = append(listArgs, status)
	}
	listQ += fmt.Sprintf(` ORDER BY se.created_at DESC LIMIT %d OFFSET %d`, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("list invitations: %w", err)
	}
	defer rows.Close()

	var results []EnrollmentResponse
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			continue
		}
		enr, err := s.getEnrollment(ctx, id)
		if err == nil {
			results = append(results, *enr)
		}
	}
	if results == nil {
		results = []EnrollmentResponse{}
	}
	return results, total, nil
}

// List requests for a teacher's series (student-initiated)
func (s *Service) ListSeriesRequests(ctx context.Context, seriesID, teacherID string, page, limit int) ([]EnrollmentResponse, int64, error) {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)
	offset := (page - 1) * limit

	// Verify teacher owns series
	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT teacher_id FROM session_series WHERE id = $1`, sid).Scan(&ownerID)
	if err != nil {
		return nil, 0, ErrSeriesNotFound
	}
	if ownerID != tid {
		return nil, 0, ErrNotAuthorized
	}

	var total int64
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND initiated_by = 'student' AND status = 'requested'`,
		sid,
	).Scan(&total)

	rows, err := s.db.Pool.Query(ctx,
		fmt.Sprintf(`SELECT id FROM session_enrollments WHERE series_id = $1 AND initiated_by = 'student' AND status = 'requested'
		 ORDER BY created_at DESC LIMIT %d OFFSET %d`, limit, offset), sid)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var results []EnrollmentResponse
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			continue
		}
		enr, err := s.getEnrollment(ctx, id)
		if err == nil {
			results = append(results, *enr)
		}
	}
	if results == nil {
		results = []EnrollmentResponse{}
	}
	return results, total, nil
}

// ═══════════════════════════════════════════════════════════════
// Finalize & Pay Platform Fee
// ═══════════════════════════════════════════════════════════════

// Teacher finalizes series — marks it as ready (no payment required, stars are per-enrollment).
func (s *Service) FinalizeSeries(ctx context.Context, seriesID, teacherID string) (*SeriesResponse, error) {
	sid, _ := uuid.Parse(seriesID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership and status
	var ownerID uuid.UUID
	var isFinalized bool
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, is_finalized FROM session_series WHERE id = $1`, sid,
	).Scan(&ownerID, &isFinalized)
	if err != nil {
		return nil, ErrSeriesNotFound
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}
	if isFinalized {
		return nil, ErrAlreadyFinalized
	}

	// Count sessions
	var totalSessions int
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM sessions WHERE series_id = $1`, sid).Scan(&totalSessions)
	if totalSessions == 0 {
		return nil, ErrNoSessions
	}

	// Count accepted enrollments
	var enrolledCount int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND status = 'accepted'`, sid,
	).Scan(&enrolledCount)
	if enrolledCount == 0 {
		return nil, ErrNoEnrollments
	}

	// Mark series as finalized
	now := time.Now()
	_, _ = s.db.Pool.Exec(ctx,
		`UPDATE session_series SET is_finalized = true, finalized_at = $1, status = 'finalized', updated_at = $1 WHERE id = $2`,
		now, sid,
	)

	return s.GetSeries(ctx, seriesID, teacherID)
}

// Teacher confirms payment with BaridiMob reference
func (s *Service) ConfirmPayment(ctx context.Context, feeID, teacherID string, req ConfirmPaymentRequest) (*PlatformFeeResponse, error) {
	fid, _ := uuid.Parse(feeID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership
	var dbTeacherID uuid.UUID
	var dbStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status::text FROM platform_fees WHERE id = $1`, fid,
	).Scan(&dbTeacherID, &dbStatus)
	if err != nil {
		return nil, ErrFeeNotFound
	}
	if dbTeacherID != tid {
		return nil, ErrNotAuthorized
	}
	if dbStatus != "pending" {
		return nil, ErrFeeAlreadyPaid
	}

	// Update fee status (will be verified by admin)
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE platform_fees SET provider_ref = $1 WHERE id = $2`,
		req.ProviderRef, fid,
	)
	if err != nil {
		return nil, fmt.Errorf("confirm payment: %w", err)
	}

	return s.getFee(ctx, fid)
}

// List pending fees for teacher
func (s *Service) ListPendingFees(ctx context.Context, teacherID string) ([]PlatformFeeResponse, error) {
	tid, _ := uuid.Parse(teacherID)

	rows, err := s.db.Pool.Query(ctx,
		`SELECT id FROM platform_fees WHERE teacher_id = $1 AND status = 'pending' ORDER BY created_at DESC`, tid,
	)
	if err != nil {
		return nil, fmt.Errorf("list fees: %w", err)
	}
	defer rows.Close()

	var fees []PlatformFeeResponse
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			continue
		}
		fee, err := s.getFee(ctx, id)
		if err == nil {
			fees = append(fees, *fee)
		}
	}
	if fees == nil {
		fees = []PlatformFeeResponse{}
	}
	return fees, nil
}

// ═══════════════════════════════════════════════════════════════
// Admin: Verify Payment
// ═══════════════════════════════════════════════════════════════

func (s *Service) AdminVerifyPayment(ctx context.Context, feeID, adminID string, approved bool, notes string) (*PlatformFeeResponse, error) {
	fid, _ := uuid.Parse(feeID)
	aid, _ := uuid.Parse(adminID)

	now := time.Now()
	status := "completed"
	if !approved {
		status = "failed"
	}

	_, err := s.db.Pool.Exec(ctx,
		`UPDATE platform_fees SET status = $1::platform_fee_status, admin_verified_by = $2, admin_notes = $3, paid_at = $4 WHERE id = $5`,
		status, aid, notes, now, fid,
	)
	if err != nil {
		return nil, fmt.Errorf("verify payment: %w", err)
	}

	return s.getFee(ctx, fid)
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
		`SELECT teacher_id, series_id, status::text, COALESCE(livekit_room_id,''), session_type::text
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

	// If student, check enrollment (star already paid at acceptance time)
	if !isTeacher {
		if seriesID == nil {
			return nil, ErrNotEnrolled
		}

		// Check enrollment
		var enrollStatus string
		err := s.db.Pool.QueryRow(ctx,
			`SELECT status::text FROM session_enrollments WHERE series_id = $1 AND student_id = $2`, *seriesID, uid,
		).Scan(&enrollStatus)
		if err != nil || enrollStatus != "accepted" {
			return nil, ErrNotEnrolled
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

// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

func (s *Service) starCostForType(sessionType string) float64 {
	if sessionType == "one_on_one" {
		return PrivateStarCost
	}
	return GroupStarCost
}

func (s *Service) getEnrollment(ctx context.Context, enrollID uuid.UUID) (*EnrollmentResponse, error) {
	var enr EnrollmentResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT se.id, se.series_id, ss.title, ss.teacher_id, 
		        t.first_name || ' ' || t.last_name,
		        se.student_id, u.first_name || ' ' || u.last_name,
		        se.initiated_by, se.status::text, ss.session_type::text,
		        (SELECT COUNT(*) FROM sessions WHERE series_id = se.series_id),
		        ss.duration_hours,
		        se.invited_at, se.requested_at, se.accepted_at, se.created_at
		 FROM session_enrollments se
		 JOIN session_series ss ON ss.id = se.series_id
		 JOIN users t ON t.id = ss.teacher_id
		 JOIN users u ON u.id = se.student_id
		 WHERE se.id = $1`, enrollID,
	).Scan(
		&enr.ID, &enr.SeriesID, &enr.SeriesTitle, &enr.TeacherID,
		&enr.TeacherName,
		&enr.StudentID, &enr.StudentName,
		&enr.InitiatedBy, &enr.Status, &enr.SessionType,
		&enr.TotalSessions,
		&enr.DurationHours,
		&enr.InvitedAt, &enr.RequestedAt, &enr.AcceptedAt, &enr.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrEnrollmentNotFound
		}
		return nil, fmt.Errorf("get enrollment: %w", err)
	}
	return &enr, nil
}

func (s *Service) getFee(ctx context.Context, feeID uuid.UUID) (*PlatformFeeResponse, error) {
	var fee PlatformFeeResponse
	var seriesTitle string
	var providerRef, description *string
	var paidAt *time.Time
	err := s.db.Pool.QueryRow(ctx,
		`SELECT pf.id, pf.series_id, ss.title, pf.teacher_id, pf.enrolled_count, 
		        pf.total_sessions, pf.duration_hours, pf.fee_rate, pf.amount,
		        pf.status::text, pf.provider_ref, pf.description,
		        pf.created_at, pf.paid_at
		 FROM platform_fees pf
		 JOIN session_series ss ON ss.id = pf.series_id
		 WHERE pf.id = $1`, feeID,
	).Scan(
		&fee.ID, &fee.SeriesID, &seriesTitle, &fee.TeacherID, &fee.EnrolledCount,
		&fee.TotalSessions, &fee.DurationHours, &fee.FeeRate, &fee.Amount,
		&fee.Status, &providerRef, &description,
		&fee.CreatedAt, &paidAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrFeeNotFound
		}
		return nil, fmt.Errorf("get fee: %w", err)
	}
	fee.SeriesTitle = seriesTitle
	fee.ProviderRef = providerRef
	fee.PaidAt = paidAt
	if description != nil {
		fee.Description = *description
	}
	return &fee, nil
}
