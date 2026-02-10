package teacher

import (
	"context"
	"errors"
	"fmt"

	"educonnect/pkg/database"
	"educonnect/pkg/search"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrProfileNotFound  = errors.New("teacher profile not found")
	ErrOfferingNotFound = errors.New("offering not found")
	ErrNotAuthorized    = errors.New("not authorized to modify this resource")
)

type Service struct {
	db     *database.Postgres
	search *search.Meilisearch
}

func NewService(db *database.Postgres, search *search.Meilisearch) *Service {
	return &Service{db: db, search: search}
}

// ─── Profile ────────────────────────────────────────────────────

func (s *Service) GetProfile(ctx context.Context, userID string) (*TeacherProfileResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrProfileNotFound
	}

	var p TeacherProfileResponse
	var specializations []string

	err = s.db.Pool.QueryRow(ctx,
		`SELECT tp.user_id, u.first_name, u.last_name, COALESCE(u.avatar_url,''),
		        COALESCE(u.email,''), COALESCE(u.phone,''), COALESCE(u.wilaya,''),
		        COALESCE(tp.bio,''), tp.experience_years, tp.specializations,
		        tp.verification_status, tp.rating_avg, tp.rating_count,
		        tp.total_sessions, tp.total_students, tp.completion_rate
		 FROM teacher_profiles tp
		 JOIN users u ON u.id = tp.user_id
		 WHERE tp.user_id = $1`, uid,
	).Scan(
		&p.UserID, &p.FirstName, &p.LastName, &p.AvatarURL,
		&p.Email, &p.Phone, &p.Wilaya,
		&p.Bio, &p.ExperienceYears, &specializations,
		&p.VerificationStatus, &p.RatingAvg, &p.RatingCount,
		&p.TotalSessions, &p.TotalStudents, &p.CompletionRate,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrProfileNotFound
		}
		return nil, fmt.Errorf("query teacher: %w", err)
	}
	p.Specializations = specializations

	return &p, nil
}

func (s *Service) UpdateProfile(ctx context.Context, userID string, req UpdateTeacherProfileRequest) (*TeacherProfileResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrProfileNotFound
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE teacher_profiles SET
			bio              = COALESCE($2, bio),
			experience_years = COALESCE($3, experience_years),
			specializations  = COALESCE($4, specializations)
		 WHERE user_id = $1`,
		uid, req.Bio, req.ExperienceYears, req.Specializations,
	)
	if err != nil {
		return nil, fmt.Errorf("update teacher: %w", err)
	}

	// Re-index in Meilisearch
	profile, err := s.GetProfile(ctx, userID)
	if err == nil && s.search != nil {
		_ = s.search.IndexTeacher(map[string]interface{}{
			"id":              profile.UserID.String(),
			"name":            profile.FirstName + " " + profile.LastName,
			"first_name":      profile.FirstName,
			"last_name":       profile.LastName,
			"wilaya":          profile.Wilaya,
			"bio":             profile.Bio,
			"specializations": profile.Specializations,
			"rating_avg":      profile.RatingAvg,
			"total_sessions":  profile.TotalSessions,
		})
	}

	return profile, nil
}

// ─── Offerings ──────────────────────────────────────────────────

func (s *Service) CreateOffering(ctx context.Context, teacherID string, req CreateOfferingRequest) (*OfferingResponse, error) {
	uid, _ := uuid.Parse(teacherID)

	maxStudents := req.MaxStudents
	if maxStudents == 0 {
		maxStudents = 1
	}

	var o OfferingResponse
	err := s.db.Pool.QueryRow(ctx,
		`WITH ins AS (
			INSERT INTO offerings (teacher_id, subject_id, level_id, session_type, price_per_hour, max_students, free_trial_enabled, free_trial_duration)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			RETURNING *
		)
		SELECT ins.id, ins.teacher_id, ins.subject_id, s.name_fr, ins.level_id, l.name, l.code,
		       ins.session_type, ins.price_per_hour, ins.max_students,
		       ins.free_trial_enabled, ins.free_trial_duration, ins.is_active
		FROM ins
		JOIN subjects s ON s.id = ins.subject_id
		JOIN levels l ON l.id = ins.level_id`,
		uid, req.SubjectID, req.LevelID, req.SessionType,
		req.PricePerHour, maxStudents, req.FreeTrialEnabled, req.FreeTrialDuration,
	).Scan(
		&o.ID, &o.TeacherID, &o.SubjectID, &o.SubjectName, &o.LevelID, &o.LevelName, &o.LevelCode,
		&o.SessionType, &o.PricePerHour, &o.MaxStudents,
		&o.FreeTrialEnabled, &o.FreeTrialDuration, &o.IsActive,
	)
	if err != nil {
		return nil, fmt.Errorf("create offering: %w", err)
	}

	return &o, nil
}

func (s *Service) ListOfferings(ctx context.Context, teacherID string) ([]OfferingResponse, error) {
	uid, _ := uuid.Parse(teacherID)

	rows, err := s.db.Pool.Query(ctx,
		`SELECT o.id, o.teacher_id, o.subject_id, s.name_fr, o.level_id, l.name, l.code,
		        o.session_type, o.price_per_hour, o.max_students,
		        o.free_trial_enabled, o.free_trial_duration, o.is_active
		 FROM offerings o
		 JOIN subjects s ON s.id = o.subject_id
		 JOIN levels l ON l.id = o.level_id
		 WHERE o.teacher_id = $1
		 ORDER BY o.is_active DESC, l."order", s.name_fr`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("list offerings: %w", err)
	}
	defer rows.Close()

	var offerings []OfferingResponse
	for rows.Next() {
		var o OfferingResponse
		if err := rows.Scan(
			&o.ID, &o.TeacherID, &o.SubjectID, &o.SubjectName, &o.LevelID, &o.LevelName, &o.LevelCode,
			&o.SessionType, &o.PricePerHour, &o.MaxStudents,
			&o.FreeTrialEnabled, &o.FreeTrialDuration, &o.IsActive,
		); err != nil {
			return nil, fmt.Errorf("scan offering: %w", err)
		}
		offerings = append(offerings, o)
	}

	return offerings, nil
}

func (s *Service) UpdateOffering(ctx context.Context, teacherID string, offeringID string, req UpdateOfferingRequest) (*OfferingResponse, error) {
	uid, _ := uuid.Parse(teacherID)
	oid, err := uuid.Parse(offeringID)
	if err != nil {
		return nil, ErrOfferingNotFound
	}

	var o OfferingResponse
	err = s.db.Pool.QueryRow(ctx,
		`WITH upd AS (
			UPDATE offerings SET
				price_per_hour     = COALESCE($3, price_per_hour),
				max_students       = COALESCE($4, max_students),
				free_trial_enabled = COALESCE($5, free_trial_enabled),
				is_active          = COALESCE($6, is_active)
			WHERE id = $1 AND teacher_id = $2
			RETURNING *
		)
		SELECT upd.id, upd.teacher_id, upd.subject_id, s.name_fr, upd.level_id, l.name, l.code,
		       upd.session_type, upd.price_per_hour, upd.max_students,
		       upd.free_trial_enabled, upd.free_trial_duration, upd.is_active
		FROM upd
		JOIN subjects s ON s.id = upd.subject_id
		JOIN levels l ON l.id = upd.level_id`,
		oid, uid, req.PricePerHour, req.MaxStudents, req.FreeTrialEnabled, req.IsActive,
	).Scan(
		&o.ID, &o.TeacherID, &o.SubjectID, &o.SubjectName, &o.LevelID, &o.LevelName, &o.LevelCode,
		&o.SessionType, &o.PricePerHour, &o.MaxStudents,
		&o.FreeTrialEnabled, &o.FreeTrialDuration, &o.IsActive,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrOfferingNotFound
		}
		return nil, fmt.Errorf("update offering: %w", err)
	}

	return &o, nil
}

func (s *Service) DeleteOffering(ctx context.Context, teacherID string, offeringID string) error {
	uid, _ := uuid.Parse(teacherID)
	oid, err := uuid.Parse(offeringID)
	if err != nil {
		return ErrOfferingNotFound
	}

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE offerings SET is_active = false WHERE id = $1 AND teacher_id = $2`, oid, uid)
	if err != nil {
		return fmt.Errorf("delete offering: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrOfferingNotFound
	}
	return nil
}

// ─── Availability ───────────────────────────────────────────────

func (s *Service) GetAvailability(ctx context.Context, teacherID string) ([]AvailabilitySlotResponse, error) {
	uid, _ := uuid.Parse(teacherID)

	rows, err := s.db.Pool.Query(ctx,
		`SELECT id, day_of_week, start_time::text, end_time::text
		 FROM availability_slots
		 WHERE teacher_id = $1 AND is_active = true
		 ORDER BY day_of_week, start_time`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("get availability: %w", err)
	}
	defer rows.Close()

	var slots []AvailabilitySlotResponse
	for rows.Next() {
		var slot AvailabilitySlotResponse
		if err := rows.Scan(&slot.ID, &slot.DayOfWeek, &slot.StartTime, &slot.EndTime); err != nil {
			return nil, err
		}
		slots = append(slots, slot)
	}
	return slots, nil
}

func (s *Service) SetAvailability(ctx context.Context, teacherID string, req SetAvailabilityRequest) ([]AvailabilitySlotResponse, error) {
	uid, _ := uuid.Parse(teacherID)

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Clear existing slots
	_, err = tx.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, uid)
	if err != nil {
		return nil, fmt.Errorf("clear slots: %w", err)
	}

	// Insert new slots
	var slots []AvailabilitySlotResponse
	for _, input := range req.Slots {
		var slot AvailabilitySlotResponse
		err = tx.QueryRow(ctx,
			`INSERT INTO availability_slots (teacher_id, day_of_week, start_time, end_time)
			 VALUES ($1, $2, $3::time, $4::time)
			 RETURNING id, day_of_week, start_time::text, end_time::text`,
			uid, input.DayOfWeek, input.StartTime, input.EndTime,
		).Scan(&slot.ID, &slot.DayOfWeek, &slot.StartTime, &slot.EndTime)
		if err != nil {
			return nil, fmt.Errorf("insert slot: %w", err)
		}
		slots = append(slots, slot)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return slots, nil
}

// ─── Earnings ───────────────────────────────────────────────────

func (s *Service) GetEarnings(ctx context.Context, teacherID string, page, limit int) (*EarningsResponse, error) {
	uid, _ := uuid.Parse(teacherID)

	var resp EarningsResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT
			COALESCE(SUM(net_amount), 0),
			COALESCE(SUM(CASE WHEN created_at >= date_trunc('month', NOW()) THEN net_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN status = 'completed' AND created_at >= date_trunc('month', NOW()) THEN net_amount ELSE 0 END), 0)
		 FROM transactions WHERE payee_id = $1 AND status = 'completed'`, uid,
	).Scan(&resp.TotalEarnings, &resp.MonthEarnings, &resp.AvailableBalance)
	if err != nil {
		return nil, fmt.Errorf("earnings: %w", err)
	}

	offset := (page - 1) * limit
	rows, err := s.db.Pool.Query(ctx,
		`SELECT t.id, u.first_name || ' ' || u.last_name, t.amount, t.commission, t.net_amount,
		        t.payment_method, t.status, t.created_at
		 FROM transactions t
		 JOIN users u ON u.id = t.payer_id
		 WHERE t.payee_id = $1
		 ORDER BY t.created_at DESC
		 LIMIT $2 OFFSET $3`, uid, limit, offset,
	)
	if err != nil {
		return nil, fmt.Errorf("transactions: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var tx TransactionSummary
		if err := rows.Scan(&tx.ID, &tx.PayerName, &tx.Amount, &tx.Commission, &tx.NetAmount, &tx.PaymentMethod, &tx.Status, &tx.CreatedAt); err != nil {
			return nil, err
		}
		resp.Transactions = append(resp.Transactions, tx)
	}

	return &resp, nil
}

// ─── Search / List Teachers ─────────────────────────────────────

func (s *Service) ListTeachers(ctx context.Context, wilaya string, minRating float64, page, limit int) ([]TeacherProfileResponse, int64, error) {
	offset := (page - 1) * limit

	var countArgs []interface{}
	countQuery := `SELECT COUNT(*) FROM teacher_profiles tp JOIN users u ON u.id = tp.user_id WHERE tp.verification_status = 'verified' AND u.is_active = true`
	argIdx := 1

	if wilaya != "" {
		countQuery += fmt.Sprintf(` AND u.wilaya = $%d`, argIdx)
		countArgs = append(countArgs, wilaya)
		argIdx++
	}
	if minRating > 0 {
		countQuery += fmt.Sprintf(` AND tp.rating_avg >= $%d`, argIdx)
		countArgs = append(countArgs, minRating)
	}

	var total int64
	err := s.db.Pool.QueryRow(ctx, countQuery, countArgs...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("count teachers: %w", err)
	}

	rows, err := s.db.Pool.Query(ctx,
		`SELECT tp.user_id, u.first_name, u.last_name, COALESCE(u.avatar_url,''),
		        COALESCE(u.email,''), COALESCE(u.phone,''), COALESCE(u.wilaya,''),
		        COALESCE(tp.bio,''), tp.experience_years, tp.specializations,
		        tp.verification_status, tp.rating_avg, tp.rating_count,
		        tp.total_sessions, tp.total_students, tp.completion_rate
		 FROM teacher_profiles tp
		 JOIN users u ON u.id = tp.user_id
		 WHERE tp.verification_status = 'verified' AND u.is_active = true
		   AND ($1::text = '' OR u.wilaya = $1)
		   AND ($2::decimal = 0 OR tp.rating_avg >= $2)
		 ORDER BY tp.rating_avg DESC, tp.total_sessions DESC
		 LIMIT $3 OFFSET $4`,
		wilaya, minRating, limit, offset,
	)
	if err != nil {
		return nil, 0, fmt.Errorf("list teachers: %w", err)
	}
	defer rows.Close()

	var teachers []TeacherProfileResponse
	for rows.Next() {
		var t TeacherProfileResponse
		var specs []string
		if err := rows.Scan(
			&t.UserID, &t.FirstName, &t.LastName, &t.AvatarURL,
			&t.Email, &t.Phone, &t.Wilaya,
			&t.Bio, &t.ExperienceYears, &specs,
			&t.VerificationStatus, &t.RatingAvg, &t.RatingCount,
			&t.TotalSessions, &t.TotalStudents, &t.CompletionRate,
		); err != nil {
			return nil, 0, err
		}
		t.Specializations = specs
		teachers = append(teachers, t)
	}

	return teachers, total, nil
}

// ─── Dashboard ──────────────────────────────────────────────────

func (s *Service) GetDashboard(ctx context.Context, teacherID string) (*TeacherDashboardResponse, error) {
	profile, err := s.GetProfile(ctx, teacherID)
	if err != nil {
		return nil, err
	}

	earnings, err := s.GetEarnings(ctx, teacherID, 1, 5)
	if err != nil {
		earnings = &EarningsResponse{}
	}

	uid, _ := uuid.Parse(teacherID)

	// Upcoming sessions
	rows, err := s.db.Pool.Query(ctx,
		`SELECT s.id, s.title, s.start_time, s.end_time, s.status, COUNT(sp.id)
		 FROM sessions s
		 LEFT JOIN session_participants sp ON sp.session_id = s.id
		 WHERE s.teacher_id = $1 AND s.status = 'scheduled' AND s.start_time > NOW()
		 GROUP BY s.id
		 ORDER BY s.start_time ASC
		 LIMIT 5`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("upcoming sessions: %w", err)
	}
	defer rows.Close()

	var upcoming []SessionBrief
	for rows.Next() {
		var sb SessionBrief
		if err := rows.Scan(&sb.ID, &sb.Title, &sb.StartTime, &sb.EndTime, &sb.Status, &sb.ParticipantCount); err != nil {
			return nil, err
		}
		upcoming = append(upcoming, sb)
	}

	// Recent reviews
	reviewRows, err := s.db.Pool.Query(ctx,
		`SELECT r.id, u.first_name || ' ' || u.last_name, r.overall_rating, COALESCE(r.review_text,''), r.created_at
		 FROM reviews r
		 JOIN users u ON u.id = r.reviewer_id
		 WHERE r.teacher_id = $1
		 ORDER BY r.created_at DESC LIMIT 5`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("recent reviews: %w", err)
	}
	defer reviewRows.Close()

	var reviews []ReviewBrief
	for reviewRows.Next() {
		var rb ReviewBrief
		if err := reviewRows.Scan(&rb.ID, &rb.ReviewerName, &rb.Rating, &rb.ReviewText, &rb.CreatedAt); err != nil {
			return nil, err
		}
		reviews = append(reviews, rb)
	}

	return &TeacherDashboardResponse{
		Profile:          *profile,
		UpcomingSessions: upcoming,
		Earnings:         *earnings,
		RecentReviews:    reviews,
	}, nil
}
