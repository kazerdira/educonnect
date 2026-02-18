package booking

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"educonnect/internal/notification"
	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrBookingNotFound  = errors.New("booking request not found")
	ErrUnauthorized     = errors.New("unauthorized action")
	ErrInvalidStatus    = errors.New("invalid booking status for this action")
	ErrSlotNotAvailable = errors.New("teacher is not available at this time")
	ErrAlreadyBooked    = errors.New("this time slot is already booked")
	ErrTimeConflict     = errors.New("time slot conflict")
	ErrSessionFull      = errors.New("session is full")
)

type Service struct {
	db     *database.Postgres
	notifs *notification.Service
}

func NewService(db *database.Postgres, notifs *notification.Service) *Service {
	return &Service{db: db, notifs: notifs}
}

// CreateBookingRequest creates a new booking request from a student or parent.
// If callerID is a parent and ForChildID is set, the booking is for the child.
// If callerID is a student, they book for themselves.
func (s *Service) CreateBookingRequest(ctx context.Context, callerID string, callerRole string, req CreateBookingRequest) (*BookingRequestResponse, error) {
	callerUID, err := uuid.Parse(callerID)
	if err != nil {
		return nil, fmt.Errorf("invalid caller id: %w", err)
	}
	tuid, err := uuid.Parse(req.TeacherID)
	if err != nil {
		return nil, fmt.Errorf("invalid teacher id: %w", err)
	}

	// Determine the actual student_id and parent_id based on caller role
	var studentID uuid.UUID
	var bookedByParentID *uuid.UUID

	if callerRole == "parent" {
		// Parent must specify which child the booking is for
		if req.ForChildID == "" {
			return nil, fmt.Errorf("parent must specify for_child_id when booking")
		}
		childUID, err := uuid.Parse(req.ForChildID)
		if err != nil {
			return nil, fmt.Errorf("invalid for_child_id: %w", err)
		}

		// Verify parent-child relationship
		var isParent bool
		err = s.db.Pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM student_profiles WHERE user_id = $1 AND parent_id = $2)`,
			childUID, callerUID,
		).Scan(&isParent)
		if err != nil {
			return nil, fmt.Errorf("verify parent relationship: %w", err)
		}
		if !isParent {
			return nil, fmt.Errorf("you are not the parent of this child")
		}

		studentID = childUID
		bookedByParentID = &callerUID
	} else {
		// Student books for themselves
		studentID = callerUID
	}

	// Parse the requested date and times
	reqDate, err := time.Parse("2006-01-02", req.RequestedDate)
	if err != nil {
		return nil, fmt.Errorf("invalid requested_date format (use YYYY-MM-DD): %w", err)
	}

	// Validate start_time and end_time format (HH:MM)
	_, err = time.Parse("15:04", req.StartTime)
	if err != nil {
		return nil, fmt.Errorf("invalid start_time format (use HH:MM): %w", err)
	}
	_, err = time.Parse("15:04", req.EndTime)
	if err != nil {
		return nil, fmt.Errorf("invalid end_time format (use HH:MM): %w", err)
	}

	// Check teacher availability for this day/time
	dayOfWeek := int(reqDate.Weekday())
	var available bool
	err = s.db.Pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM availability_slots
			WHERE teacher_id = $1
			AND day_of_week = $2
			AND start_time <= $3::time
			AND end_time >= $4::time
		)`,
		tuid, dayOfWeek, req.StartTime, req.EndTime,
	).Scan(&available)
	if err != nil {
		return nil, fmt.Errorf("check availability: %w", err)
	}
	if !available {
		// Fetch the teacher's available slots for this day to include in the error
		rows, qErr := s.db.Pool.Query(ctx,
			`SELECT start_time::text, end_time::text
			 FROM availability_slots
			 WHERE teacher_id = $1 AND day_of_week = $2
			 ORDER BY start_time`,
			tuid, dayOfWeek,
		)
		var slots []string
		if qErr == nil {
			defer rows.Close()
			for rows.Next() {
				var st, et string
				if rows.Scan(&st, &et) == nil {
					slots = append(slots, st[:5]+"-"+et[:5])
				}
			}
		}
		if len(slots) == 0 {
			dayNames := []string{"dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"}
			return nil, fmt.Errorf("%w: L'enseignant n'a aucune disponibilité le %s.", ErrSlotNotAvailable, dayNames[dayOfWeek])
		}
		return nil, fmt.Errorf("%w: Ce créneau n'est pas dans les disponibilités de l'enseignant. Créneaux disponibles ce jour : %s",
			ErrSlotNotAvailable, strings.Join(slots, ", "))
	}

	// Check no conflicting accepted booking exists
	// For individual bookings: block if ANY accepted booking overlaps
	// For group bookings: only block if an accepted INDIVIDUAL booking overlaps
	//   (group bookings at the same time will be auto-merged when teacher accepts)
	var conflict bool
	conflictSessionTypeFilter := ""
	if req.SessionType == "group" {
		conflictSessionTypeFilter = "AND session_type = 'individual'"
	}
	err = s.db.Pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM booking_requests
			WHERE teacher_id = $1
			AND requested_date = $2
			AND status = 'accepted'
			`+conflictSessionTypeFilter+`
			AND (
				(start_time <= $3::time AND end_time > $3::time) OR
				(start_time < $4::time AND end_time >= $4::time) OR
				(start_time >= $3::time AND end_time <= $4::time)
			)
		)`,
		tuid, reqDate, req.StartTime, req.EndTime,
	).Scan(&conflict)
	if err != nil {
		return nil, fmt.Errorf("check conflicts: %w", err)
	}
	if conflict {
		return nil, ErrAlreadyBooked
	}

	// Parse offering ID if provided
	var offeringID *uuid.UUID
	if req.OfferingID != "" {
		oid, e := uuid.Parse(req.OfferingID)
		if e == nil {
			offeringID = &oid
		}
	}

	bookingID := uuid.New()
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO booking_requests 
			(id, student_id, teacher_id, offering_id, session_type, requested_date, start_time, end_time, message, purpose, status, booked_by_parent_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7::time, $8::time, $9, $10, 'pending', $11)`,
		bookingID, studentID, tuid, offeringID, req.SessionType,
		reqDate, req.StartTime, req.EndTime,
		req.Message, req.Purpose, bookedByParentID,
	)
	if err != nil {
		return nil, fmt.Errorf("insert booking: %w", err)
	}

	return s.GetBookingRequest(ctx, bookingID.String(), callerID)
}

// GetBookingRequest retrieves a single booking request.
func (s *Service) GetBookingRequest(ctx context.Context, bookingID, callerID string) (*BookingRequestResponse, error) {
	bid, err := uuid.Parse(bookingID)
	if err != nil {
		return nil, ErrBookingNotFound
	}

	var br BookingRequestResponse
	var requestedDate time.Time
	var startTime, endTime, createdAt, updatedAt time.Time
	var offeringID, sessionID, seriesID *string
	var subjectName, levelName, declineReason *string
	var bookedByParentID *string
	var bookedByParentName *string

	err = s.db.Pool.QueryRow(ctx,
		`SELECT br.id, br.student_id, us.first_name || ' ' || us.last_name,
		        br.teacher_id, ut.first_name || ' ' || ut.last_name,
		        br.offering_id::text, COALESCE(sub.name_fr, ''), COALESCE(lvl.name, ''),
		        br.session_type, br.requested_date, br.start_time, br.end_time,
		        COALESCE(br.message, ''), COALESCE(br.purpose, ''), br.status,
		        br.decline_reason, br.session_id::text, br.series_id::text,
		        br.created_at, br.updated_at,
		        br.booked_by_parent_id::text,
		        (SELECT first_name || ' ' || last_name FROM users WHERE id = br.booked_by_parent_id)
		 FROM booking_requests br
		 JOIN users us ON us.id = br.student_id
		 JOIN users ut ON ut.id = br.teacher_id
		 LEFT JOIN offerings o ON o.id = br.offering_id
		 LEFT JOIN subjects sub ON sub.id = o.subject_id
		 LEFT JOIN levels lvl ON lvl.id = o.level_id
		 WHERE br.id = $1`, bid,
	).Scan(
		&br.ID, &br.StudentID, &br.StudentName,
		&br.TeacherID, &br.TeacherName,
		&offeringID, &subjectName, &levelName,
		&br.SessionType, &requestedDate, &startTime, &endTime,
		&br.Message, &br.Purpose, &br.Status,
		&declineReason, &sessionID, &seriesID,
		&createdAt, &updatedAt,
		&bookedByParentID, &bookedByParentName,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrBookingNotFound
		}
		return nil, fmt.Errorf("get booking: %w", err)
	}

	br.OfferingID = offeringID
	if subjectName != nil {
		br.SubjectName = *subjectName
	}
	if levelName != nil {
		br.LevelName = *levelName
	}
	if declineReason != nil {
		br.DeclineReason = *declineReason
	}
	br.SessionID = sessionID
	br.SeriesID = seriesID
	br.BookedByParentID = bookedByParentID
	if bookedByParentName != nil {
		br.BookedByParentName = *bookedByParentName
	}
	br.RequestedDate = requestedDate.Format("2006-01-02")
	br.StartTime = startTime.Format("15:04")
	br.EndTime = endTime.Format("15:04")
	br.CreatedAt = createdAt
	br.UpdatedAt = updatedAt

	return &br, nil
}

// ListBookingRequests lists booking requests for a user (as student, teacher, or parent).
func (s *Service) ListBookingRequests(ctx context.Context, userID string, q ListBookingsQuery) ([]BookingRequestResponse, int64, error) {
	uid, _ := uuid.Parse(userID)
	offset := (q.Page - 1) * q.Limit

	// Build query based on role
	var roleFilter string
	switch q.Role {
	case "as_teacher":
		roleFilter = "br.teacher_id"
	case "as_parent":
		roleFilter = "br.booked_by_parent_id"
	default: // as_student
		roleFilter = "br.student_id"
	}

	countQ := fmt.Sprintf(`SELECT COUNT(*) FROM booking_requests br WHERE %s = $1`, roleFilter)
	args := []interface{}{uid}

	if q.Status != "" {
		countQ += ` AND status = $2`
		args = append(args, q.Status)
	}

	var total int64
	s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total)

	listQ := fmt.Sprintf(`
		SELECT br.id, br.student_id, us.first_name || ' ' || us.last_name,
		       br.teacher_id, ut.first_name || ' ' || ut.last_name,
		       br.offering_id::text, COALESCE(sub.name_fr, ''), COALESCE(lvl.name, ''),
		       br.session_type, br.requested_date, br.start_time, br.end_time,
		       COALESCE(br.message, ''), COALESCE(br.purpose, ''), br.status,
		       br.decline_reason, br.session_id::text, br.series_id::text,
		       br.created_at, br.updated_at,
		       br.booked_by_parent_id::text,
		       (SELECT first_name || ' ' || last_name FROM users WHERE id = br.booked_by_parent_id)
		FROM booking_requests br
		JOIN users us ON us.id = br.student_id
		JOIN users ut ON ut.id = br.teacher_id
		LEFT JOIN offerings o ON o.id = br.offering_id
		LEFT JOIN subjects sub ON sub.id = o.subject_id
		LEFT JOIN levels lvl ON lvl.id = o.level_id
		WHERE %s = $1`, roleFilter)

	listArgs := []interface{}{uid}
	argIdx := 2

	if q.Status != "" {
		listQ += fmt.Sprintf(` AND br.status = $%d`, argIdx)
		listArgs = append(listArgs, q.Status)
		argIdx++
	}

	listQ += fmt.Sprintf(` ORDER BY br.created_at DESC LIMIT %d OFFSET %d`, q.Limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("list bookings: %w", err)
	}
	defer rows.Close()

	var results []BookingRequestResponse
	for rows.Next() {
		var br BookingRequestResponse
		var requestedDate time.Time
		var startTime, endTime, createdAt, updatedAt time.Time
		var offeringID, sessionID, seriesID, declineReason *string
		var subjectName, levelName *string
		var bookedByParentID, bookedByParentName *string

		err := rows.Scan(
			&br.ID, &br.StudentID, &br.StudentName,
			&br.TeacherID, &br.TeacherName,
			&offeringID, &subjectName, &levelName,
			&br.SessionType, &requestedDate, &startTime, &endTime,
			&br.Message, &br.Purpose, &br.Status,
			&declineReason, &sessionID, &seriesID,
			&createdAt, &updatedAt,
			&bookedByParentID, &bookedByParentName,
		)
		if err != nil {
			continue
		}

		br.OfferingID = offeringID
		if subjectName != nil {
			br.SubjectName = *subjectName
		}
		if levelName != nil {
			br.LevelName = *levelName
		}
		if declineReason != nil {
			br.DeclineReason = *declineReason
		}
		br.SessionID = sessionID
		br.SeriesID = seriesID
		br.BookedByParentID = bookedByParentID
		if bookedByParentName != nil {
			br.BookedByParentName = *bookedByParentName
		}
		br.RequestedDate = requestedDate.Format("2006-01-02")
		br.StartTime = startTime.Format("15:04")
		br.EndTime = endTime.Format("15:04")
		br.CreatedAt = createdAt
		br.UpdatedAt = updatedAt

		results = append(results, br)
	}

	if results == nil {
		results = []BookingRequestResponse{}
	}

	return results, total, nil
}

// AcceptBookingRequest accepts a booking and creates a session series + session + enrollment.
// If ExistingSeriesID is provided, the student is added to that series instead.
func (s *Service) AcceptBookingRequest(ctx context.Context, bookingID, teacherID string, req AcceptBookingRequest) (*BookingRequestResponse, error) {
	bid, err := uuid.Parse(bookingID)
	if err != nil {
		return nil, ErrBookingNotFound
	}
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership and status
	var ownerID uuid.UUID
	var status string
	var studentID uuid.UUID
	var requestedDate time.Time
	var startTime, endTime string
	var sessionType string
	var offeringID *uuid.UUID

	err = s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status, student_id, requested_date, 
		        start_time::text, end_time::text, session_type, offering_id
		 FROM booking_requests WHERE id = $1`, bid,
	).Scan(&ownerID, &status, &studentID, &requestedDate, &startTime, &endTime, &sessionType, &offeringID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrBookingNotFound
		}
		return nil, fmt.Errorf("get booking: %w", err)
	}

	if ownerID != tid {
		return nil, ErrUnauthorized
	}
	if status != "pending" {
		return nil, ErrInvalidStatus
	}

	// Convert booking session_type to DB enum (individual -> one_on_one)
	sessionTypeForDB := sessionType
	if sessionType == "individual" {
		sessionTypeForDB = "one_on_one"
	}

	// Parse times
	startDT := requestedDate.Format("2006-01-02") + "T" + startTime[:5] + ":00Z"
	endDT := requestedDate.Format("2006-01-02") + "T" + endTime[:5] + ":00Z"
	startParsed, _ := time.Parse(time.RFC3339, startDT)
	endParsed, _ := time.Parse(time.RFC3339, endDT)

	durationHours := endParsed.Sub(startParsed).Hours()
	if durationHours < 1.0 {
		durationHours = 1.0
	}
	if durationHours > 4.0 {
		durationHours = 4.0
	}

	title := req.Title
	if title == "" {
		title = "Séance du " + requestedDate.Format("02/01/2006")
	}

	maxStudents := 1
	if sessionTypeForDB == "group" {
		maxStudents = 10
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var seriesID uuid.UUID
	var sessionID uuid.UUID

	if req.ExistingSeriesID != "" {
		// ── Add to existing series ────────────────────────────────
		existingSID, err := uuid.Parse(req.ExistingSeriesID)
		if err != nil {
			return nil, fmt.Errorf("invalid existing_series_id: %w", err)
		}

		// Verify teacher owns the series and it's not finalized
		var seriesOwner uuid.UUID
		var seriesMaxStudents int
		var seriesStatus string
		var seriesDuration float64
		err = tx.QueryRow(ctx,
			`SELECT teacher_id, max_students, status::text, duration_hours FROM session_series WHERE id = $1`, existingSID,
		).Scan(&seriesOwner, &seriesMaxStudents, &seriesStatus, &seriesDuration)
		if err != nil {
			return nil, fmt.Errorf("existing series not found")
		}
		if seriesOwner != tid {
			return nil, ErrUnauthorized
		}
		if seriesStatus == "finalized" || seriesStatus == "completed" || seriesStatus == "cancelled" {
			return nil, fmt.Errorf("cannot add to a %s series", seriesStatus)
		}

		// Check capacity
		var enrolled int
		_ = tx.QueryRow(ctx,
			`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND status NOT IN ('declined', 'removed')`,
			existingSID,
		).Scan(&enrolled)
		if enrolled >= seriesMaxStudents {
			return nil, fmt.Errorf("series is full (%d/%d)", enrolled, seriesMaxStudents)
		}

		seriesID = existingSID

		// Create a new session within this existing series
		sessionID = uuid.New()
		var nextSessionNum int
		_ = tx.QueryRow(ctx, `SELECT COALESCE(MAX(session_number), 0) + 1 FROM sessions WHERE series_id = $1`, seriesID).Scan(&nextSessionNum)

		_, err = tx.Exec(ctx,
			`INSERT INTO sessions (id, teacher_id, offering_id, series_id, session_number, title, description, session_type, start_time, end_time, max_participants, price, status)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'scheduled')`,
			sessionID, tid, offeringID, seriesID, nextSessionNum, title, req.Description, sessionTypeForDB, startParsed, endParsed, seriesMaxStudents, req.Price,
		)
		if err != nil {
			return nil, fmt.Errorf("create session in existing series: %w", err)
		}

	} else {
		// ── Check if teacher already has a session at this exact time ──
		var existingSessionID, existingSeriesID uuid.UUID
		var existingSessionType string
		var existingMaxParticipants int
		var existingParticipantCount int
		var existingOfferingID *uuid.UUID

		err = tx.QueryRow(ctx,
			`SELECT s.id, s.series_id, s.session_type::text, s.max_participants,
			        (SELECT COUNT(*) FROM session_participants sp WHERE sp.session_id = s.id),
			        s.offering_id
			 FROM sessions s
			 WHERE s.teacher_id = $1
			   AND s.start_time = $2
			   AND s.end_time = $3
			   AND s.status IN ('scheduled', 'live')
			 LIMIT 1`,
			tid, startParsed, endParsed,
		).Scan(&existingSessionID, &existingSeriesID, &existingSessionType, &existingMaxParticipants, &existingParticipantCount, &existingOfferingID)

		if err == nil {
			// Teacher already has a session at this time slot — cannot double-book
			if existingSessionType == "one_on_one" {
				return nil, fmt.Errorf("%w: Vous avez déjà une séance individuelle à cet horaire. Proposez un autre créneau à cet élève via la messagerie.", ErrTimeConflict)
			}
			if sessionTypeForDB == "one_on_one" {
				// Can't start a 1-on-1 when a group session is already scheduled
				return nil, fmt.Errorf("%w: Vous avez déjà une séance de groupe à cet horaire. Cette demande individuelle ne peut pas être acceptée ici.", ErrTimeConflict)
			}

			// Both are group — check offering (subject/level) match before merging
			offeringsMatch := (offeringID == nil && existingOfferingID == nil) ||
				(offeringID != nil && existingOfferingID != nil && *offeringID == *existingOfferingID)
			if !offeringsMatch {
				return nil, fmt.Errorf("%w: Il y a déjà une séance de groupe à cet horaire pour une autre matière. Proposez un autre créneau à cet élève.", ErrTimeConflict)
			}

			if existingParticipantCount >= existingMaxParticipants {
				return nil, fmt.Errorf("%w: La séance de groupe à cet horaire est pleine (%d/%d).", ErrSessionFull, existingParticipantCount, existingMaxParticipants)
			}

			// Reuse the existing series + session
			seriesID = existingSeriesID
			sessionID = existingSessionID

		} else if !errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("check existing session: %w", err)
		} else {
			// ── No existing session — create new series + session ──
			seriesID = uuid.New()
			now := time.Now()

			_, err = tx.Exec(ctx,
				`INSERT INTO session_series (id, teacher_id, offering_id, title, description, session_type, duration_hours, min_students, max_students, price_per_hour, status, created_at, updated_at)
				 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'active', $11, $11)`,
				seriesID, tid, offeringID, title, req.Description, sessionTypeForDB,
				durationHours, 1, maxStudents, req.Price, now,
			)
			if err != nil {
				return nil, fmt.Errorf("create series: %w", err)
			}

			// Create the session under this series
			sessionID = uuid.New()
			_, err = tx.Exec(ctx,
				`INSERT INTO sessions (id, teacher_id, offering_id, series_id, session_number, title, description, session_type, start_time, end_time, max_participants, price, status)
				 VALUES ($1, $2, $3, $4, 1, $5, $6, $7, $8, $9, $10, $11, 'scheduled')`,
				sessionID, tid, offeringID, seriesID, title, req.Description, sessionTypeForDB, startParsed, endParsed, maxStudents, req.Price,
			)
			if err != nil {
				return nil, fmt.Errorf("create session: %w", err)
			}
		}
	}

	// ── Auto-enroll the student (status = 'accepted' — they initiated the booking) ──
	enrollID := uuid.New()
	now := time.Now()
	_, err = tx.Exec(ctx,
		`INSERT INTO session_enrollments (id, series_id, student_id, initiated_by, status, requested_at, accepted_at)
		 VALUES ($1, $2, $3, 'student', 'accepted', $4, $4)
		 ON CONFLICT (series_id, student_id) DO NOTHING`,
		enrollID, seriesID, studentID, now,
	)
	if err != nil {
		return nil, fmt.Errorf("auto-enroll student: %w", err)
	}

	// ── Also add as session participant for this specific session ──
	_, err = tx.Exec(ctx,
		`INSERT INTO session_participants (session_id, student_id)
		 VALUES ($1, $2)
		 ON CONFLICT DO NOTHING`,
		sessionID, studentID,
	)
	if err != nil {
		return nil, fmt.Errorf("add participant: %w", err)
	}

	// ── Update booking status ──
	_, err = tx.Exec(ctx,
		`UPDATE booking_requests SET status = 'accepted', session_id = $1, series_id = $2, updated_at = NOW() WHERE id = $3`,
		sessionID, seriesID, bid,
	)
	if err != nil {
		return nil, fmt.Errorf("update booking: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return s.GetBookingRequest(ctx, bookingID, teacherID)
}

// DeclineBookingRequest declines a booking request.
func (s *Service) DeclineBookingRequest(ctx context.Context, bookingID, teacherID string, req DeclineBookingRequest) (*BookingRequestResponse, error) {
	bid, err := uuid.Parse(bookingID)
	if err != nil {
		return nil, ErrBookingNotFound
	}
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership and status
	var ownerID uuid.UUID
	var status string
	err = s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id, status FROM booking_requests WHERE id = $1`, bid,
	).Scan(&ownerID, &status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrBookingNotFound
		}
		return nil, fmt.Errorf("get booking: %w", err)
	}

	if ownerID != tid {
		return nil, ErrUnauthorized
	}
	if status != "pending" {
		return nil, ErrInvalidStatus
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE booking_requests SET status = 'declined', decline_reason = $1, updated_at = NOW() WHERE id = $2`,
		req.Reason, bid,
	)
	if err != nil {
		return nil, fmt.Errorf("decline booking: %w", err)
	}

	return s.GetBookingRequest(ctx, bookingID, teacherID)
}

// CancelBookingRequest allows a student to cancel their pending request.
func (s *Service) CancelBookingRequest(ctx context.Context, bookingID, studentID string) error {
	bid, err := uuid.Parse(bookingID)
	if err != nil {
		return ErrBookingNotFound
	}
	sid, _ := uuid.Parse(studentID)

	result, err := s.db.Pool.Exec(ctx,
		`UPDATE booking_requests SET status = 'cancelled', updated_at = NOW() 
		 WHERE id = $1 AND (student_id = $2 OR booked_by_parent_id = $2) AND status = 'pending'`,
		bid, sid,
	)
	if err != nil {
		return fmt.Errorf("cancel booking: %w", err)
	}

	if result.RowsAffected() == 0 {
		return ErrBookingNotFound
	}

	return nil
}

// ─── Booking Messages (conversation thread) ────────────────────

// SendMessage adds a message to a booking conversation.
// Both the teacher and the student (or booking parent) can send messages.
func (s *Service) SendMessage(ctx context.Context, bookingID, senderID string, req SendMessageRequest) (*BookingMessageResponse, error) {
	bid, err := uuid.Parse(bookingID)
	if err != nil {
		return nil, ErrBookingNotFound
	}
	uid, err := uuid.Parse(senderID)
	if err != nil {
		return nil, ErrUnauthorized
	}

	// Verify the sender is a participant of this booking (student, parent, or teacher)
	var exists bool
	err = s.db.Pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM booking_requests
			WHERE id = $1 AND (student_id = $2 OR teacher_id = $2 OR booked_by_parent_id = $2)
		)`,
		bid, uid,
	).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("check booking participant: %w", err)
	}
	if !exists {
		return nil, ErrUnauthorized
	}

	// Insert the message
	var msgID uuid.UUID
	var createdAt time.Time
	err = s.db.Pool.QueryRow(ctx,
		`INSERT INTO booking_messages (booking_id, sender_id, content)
		 VALUES ($1, $2, $3)
		 RETURNING id, created_at`,
		bid, uid, req.Content,
	).Scan(&msgID, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("insert message: %w", err)
	}

	// Fetch sender info
	var senderName, senderRole string
	err = s.db.Pool.QueryRow(ctx,
		`SELECT CONCAT(first_name, ' ', last_name), role FROM users WHERE id = $1`,
		uid,
	).Scan(&senderName, &senderRole)
	if err != nil {
		senderName = "Unknown"
		senderRole = "student"
	}

	// ── Send in-app notification to the OTHER participant(s) ────
	if s.notifs != nil {
		var studentID, teacherID uuid.UUID
		var parentID *uuid.UUID
		err = s.db.Pool.QueryRow(ctx,
			`SELECT student_id, teacher_id, booked_by_parent_id FROM booking_requests WHERE id = $1`, bid,
		).Scan(&studentID, &teacherID, &parentID)
		if err == nil {
			// Collect all participants except the sender
			recipients := []uuid.UUID{}
			if studentID != uid {
				recipients = append(recipients, studentID)
			}
			if teacherID != uid {
				recipients = append(recipients, teacherID)
			}
			if parentID != nil && *parentID != uid {
				recipients = append(recipients, *parentID)
			}

			notifData := map[string]interface{}{
				"booking_id": bookingID,
				"type":       "booking_message",
			}
			for _, rid := range recipients {
				if notifErr := s.notifs.CreateNotification(ctx, rid,
					"booking_message",
					"Nouveau message – "+senderName,
					req.Content,
					notifData,
				); notifErr != nil {
					slog.Warn("failed to create message notification", "error", notifErr, "recipient", rid)
				}
			}
		}
	}

	return &BookingMessageResponse{
		ID:         msgID.String(),
		BookingID:  bookingID,
		SenderID:   senderID,
		SenderName: senderName,
		SenderRole: senderRole,
		Content:    req.Content,
		CreatedAt:  createdAt,
	}, nil
}

// ListMessages returns the conversation thread for a booking.
// Only participants (student, parent, or teacher) can read messages.
func (s *Service) ListMessages(ctx context.Context, bookingID, callerID string, q ListMessagesQuery) ([]BookingMessageResponse, error) {
	bid, err := uuid.Parse(bookingID)
	if err != nil {
		return nil, ErrBookingNotFound
	}
	uid, err := uuid.Parse(callerID)
	if err != nil {
		return nil, ErrUnauthorized
	}

	// Verify the caller is a participant
	var exists bool
	err = s.db.Pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM booking_requests
			WHERE id = $1 AND (student_id = $2 OR teacher_id = $2 OR booked_by_parent_id = $2)
		)`,
		bid, uid,
	).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("check booking participant: %w", err)
	}
	if !exists {
		return nil, ErrUnauthorized
	}

	limit := q.Limit
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	// Build query with optional cursor-based pagination
	query := `
		SELECT bm.id, bm.booking_id, bm.sender_id,
		       CONCAT(u.first_name, ' ', u.last_name), u.role,
		       bm.content, bm.created_at
		FROM booking_messages bm
		JOIN users u ON u.id = bm.sender_id
		WHERE bm.booking_id = $1`
	args := []interface{}{bid}

	if q.Before != "" {
		beforeTime, parseErr := time.Parse(time.RFC3339, q.Before)
		if parseErr == nil {
			query += ` AND bm.created_at < $2`
			args = append(args, beforeTime)
		}
	}

	// When loading older messages (before cursor), fetch DESC then reverse to get
	// the N messages *immediately* before the cursor in chronological order.
	// Without cursor, fetch latest N in DESC then reverse.
	query += ` ORDER BY bm.created_at DESC`
	query += fmt.Sprintf(` LIMIT %d`, limit)

	rows, err := s.db.Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list messages: %w", err)
	}
	defer rows.Close()

	var messages []BookingMessageResponse
	for rows.Next() {
		var m BookingMessageResponse
		if err := rows.Scan(&m.ID, &m.BookingID, &m.SenderID, &m.SenderName, &m.SenderRole, &m.Content, &m.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan message: %w", err)
		}
		messages = append(messages, m)
	}

	if messages == nil {
		messages = []BookingMessageResponse{}
	}

	// Reverse to chronological order (oldest first)
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}
