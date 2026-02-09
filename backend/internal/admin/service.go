package admin

import (
	"context"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrUserNotFound    = errors.New("user not found")
	ErrDisputeNotFound = errors.New("dispute not found")
	ErrVerifyNotFound  = errors.New("verification not found")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ═══════════════════════════════════════════════════════════════
// Users
// ═══════════════════════════════════════════════════════════════

func (s *Service) ListUsers(ctx context.Context, role string, limit, offset int) ([]AdminUserResponse, int, error) {
	countQ := `SELECT COUNT(*) FROM users WHERE 1=1`
	listQ := `SELECT u.id, u.email, u.phone, u.role::text, u.first_name, u.last_name,
	             u.avatar_url, u.is_active, u.is_email_verified,
	             tp.verification_status::text, u.created_at
	          FROM users u
	          LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
	          WHERE 1=1`

	args := []interface{}{}
	argIdx := 1

	if role != "" {
		countQ += fmt.Sprintf(` AND role = $%d::user_role`, argIdx)
		listQ += fmt.Sprintf(` AND u.role = $%d::user_role`, argIdx)
		args = append(args, role)
		argIdx++
	}

	var total int
	if err := s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count users: %w", err)
	}

	listQ += fmt.Sprintf(` ORDER BY u.created_at DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query users: %w", err)
	}
	defer rows.Close()

	var users []AdminUserResponse
	for rows.Next() {
		var u AdminUserResponse
		if err := rows.Scan(
			&u.ID, &u.Email, &u.Phone, &u.Role, &u.FirstName, &u.LastName,
			&u.AvatarURL, &u.IsActive, &u.IsEmailVerified,
			&u.VerificationStatus, &u.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan user: %w", err)
		}
		users = append(users, u)
	}

	if users == nil {
		users = []AdminUserResponse{}
	}

	return users, total, nil
}

func (s *Service) GetUser(ctx context.Context, userID string) (*AdminUserResponse, error) {
	uid, _ := uuid.Parse(userID)

	var u AdminUserResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT u.id, u.email, u.phone, u.role::text, u.first_name, u.last_name,
		    u.avatar_url, u.is_active, u.is_email_verified,
		    tp.verification_status::text, u.created_at
		 FROM users u
		 LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
		 WHERE u.id = $1`, uid,
	).Scan(
		&u.ID, &u.Email, &u.Phone, &u.Role, &u.FirstName, &u.LastName,
		&u.AvatarURL, &u.IsActive, &u.IsEmailVerified,
		&u.VerificationStatus, &u.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("query user: %w", err)
	}

	return &u, nil
}

func (s *Service) SuspendUser(ctx context.Context, userID string) error {
	uid, _ := uuid.Parse(userID)

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE users SET is_active = false WHERE id = $1`, uid,
	)
	if err != nil {
		return fmt.Errorf("suspend user: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrUserNotFound
	}

	return nil
}

// ═══════════════════════════════════════════════════════════════
// Verifications
// ═══════════════════════════════════════════════════════════════

func (s *Service) ListVerifications(ctx context.Context, status string, limit, offset int) ([]VerificationResponse, int, error) {
	countQ := `SELECT COUNT(*) FROM teacher_profiles tp JOIN users u ON u.id = tp.user_id WHERE 1=1`
	listQ := `SELECT tp.id, tp.user_id, u.email, u.first_name, u.last_name,
	             tp.verification_status::text, tp.bio, tp.experience_years, u.created_at
	          FROM teacher_profiles tp
	          JOIN users u ON u.id = tp.user_id
	          WHERE 1=1`

	args := []interface{}{}
	argIdx := 1

	if status != "" {
		countQ += fmt.Sprintf(` AND tp.verification_status = $%d::verification_status`, argIdx)
		listQ += fmt.Sprintf(` AND tp.verification_status = $%d::verification_status`, argIdx)
		args = append(args, status)
		argIdx++
	}

	var total int
	if err := s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count verifications: %w", err)
	}

	listQ += fmt.Sprintf(` ORDER BY u.created_at ASC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query verifications: %w", err)
	}
	defer rows.Close()

	var vfs []VerificationResponse
	for rows.Next() {
		var v VerificationResponse
		if err := rows.Scan(
			&v.ID, &v.UserID, &v.Email, &v.FirstName, &v.LastName,
			&v.VerificationStatus, &v.Bio, &v.Experience, &v.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan verification: %w", err)
		}
		vfs = append(vfs, v)
	}

	if vfs == nil {
		vfs = []VerificationResponse{}
	}

	return vfs, total, nil
}

func (s *Service) ApproveTeacher(ctx context.Context, verificationID string) error {
	vid, _ := uuid.Parse(verificationID)

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE teacher_profiles SET verification_status = 'verified' WHERE id = $1`, vid,
	)
	if err != nil {
		return fmt.Errorf("approve teacher: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrVerifyNotFound
	}

	return nil
}

func (s *Service) RejectTeacher(ctx context.Context, verificationID string) error {
	vid, _ := uuid.Parse(verificationID)

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE teacher_profiles SET verification_status = 'rejected' WHERE id = $1`, vid,
	)
	if err != nil {
		return fmt.Errorf("reject teacher: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrVerifyNotFound
	}

	return nil
}

// ═══════════════════════════════════════════════════════════════
// Transactions
// ═══════════════════════════════════════════════════════════════

type AdminTransactionResponse struct {
	ID                uuid.UUID `json:"id"`
	PayerID           uuid.UUID `json:"payer_id"`
	PayerName         string    `json:"payer_name"`
	PayeeID           uuid.UUID `json:"payee_id"`
	PayeeName         string    `json:"payee_name"`
	Amount            float64   `json:"amount"`
	Commission        float64   `json:"commission"`
	NetAmount         float64   `json:"net_amount"`
	PaymentMethod     string    `json:"payment_method"`
	Status            string    `json:"status"`
	ProviderReference *string   `json:"provider_reference,omitempty"`
	CreatedAt         time.Time `json:"created_at"`
}

func (s *Service) ListTransactions(ctx context.Context, status string, limit, offset int) ([]AdminTransactionResponse, int, error) {
	countQ := `SELECT COUNT(*) FROM transactions WHERE 1=1`
	listQ := `SELECT t.id, t.payer_id, payer.first_name || ' ' || payer.last_name,
	             t.payee_id, payee.first_name || ' ' || payee.last_name,
	             t.amount, t.commission, t.net_amount, t.payment_method::text,
	             t.status::text, t.provider_reference, t.created_at
	          FROM transactions t
	          JOIN users payer ON payer.id = t.payer_id
	          JOIN users payee ON payee.id = t.payee_id
	          WHERE 1=1`

	args := []interface{}{}
	argIdx := 1

	if status != "" {
		countQ += fmt.Sprintf(` AND status = $%d::payment_status`, argIdx)
		listQ += fmt.Sprintf(` AND t.status = $%d::payment_status`, argIdx)
		args = append(args, status)
		argIdx++
	}

	var total int
	if err := s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count transactions: %w", err)
	}

	listQ += fmt.Sprintf(` ORDER BY t.created_at DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query transactions: %w", err)
	}
	defer rows.Close()

	var txns []AdminTransactionResponse
	for rows.Next() {
		var t AdminTransactionResponse
		if err := rows.Scan(
			&t.ID, &t.PayerID, &t.PayerName, &t.PayeeID, &t.PayeeName,
			&t.Amount, &t.Commission, &t.NetAmount, &t.PaymentMethod,
			&t.Status, &t.ProviderReference, &t.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan transaction: %w", err)
		}
		txns = append(txns, t)
	}

	if txns == nil {
		txns = []AdminTransactionResponse{}
	}

	return txns, total, nil
}

// ═══════════════════════════════════════════════════════════════
// Disputes
// ═══════════════════════════════════════════════════════════════

func (s *Service) ListDisputes(ctx context.Context, status string, limit, offset int) ([]DisputeResponse, int, error) {
	countQ := `SELECT COUNT(*) FROM disputes WHERE 1=1`
	listQ := `SELECT d.id, d.session_id, d.raised_by,
	             rb.first_name || ' ' || rb.last_name,
	             d.against, ag.first_name || ' ' || ag.last_name,
	             d.reason, d.description, d.status::text, d.resolution,
	             d.resolved_by, d.refund_amount, d.created_at, d.resolved_at
	          FROM disputes d
	          JOIN users rb ON rb.id = d.raised_by
	          JOIN users ag ON ag.id = d.against
	          WHERE 1=1`

	args := []interface{}{}
	argIdx := 1

	if status != "" {
		countQ += fmt.Sprintf(` AND status = $%d::dispute_status`, argIdx)
		listQ += fmt.Sprintf(` AND d.status = $%d::dispute_status`, argIdx)
		args = append(args, status)
		argIdx++
	}

	var total int
	if err := s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count disputes: %w", err)
	}

	listQ += fmt.Sprintf(` ORDER BY d.created_at DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query disputes: %w", err)
	}
	defer rows.Close()

	var disputes []DisputeResponse
	for rows.Next() {
		var d DisputeResponse
		if err := rows.Scan(
			&d.ID, &d.SessionID, &d.RaisedByID, &d.RaisedByName,
			&d.AgainstID, &d.AgainstName,
			&d.Reason, &d.Description, &d.Status, &d.Resolution,
			&d.ResolvedBy, &d.RefundAmount, &d.CreatedAt, &d.ResolvedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan dispute: %w", err)
		}
		disputes = append(disputes, d)
	}

	if disputes == nil {
		disputes = []DisputeResponse{}
	}

	return disputes, total, nil
}

func (s *Service) ResolveDispute(ctx context.Context, adminID string, disputeID string, req ResolveDisputeRequest) (*DisputeResponse, error) {
	did, _ := uuid.Parse(disputeID)
	aid, _ := uuid.Parse(adminID)

	// Check dispute exists
	var currentStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT status::text FROM disputes WHERE id = $1`, did,
	).Scan(&currentStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrDisputeNotFound
		}
		return nil, fmt.Errorf("query dispute: %w", err)
	}

	now := time.Now()
	var d DisputeResponse
	err = s.db.Pool.QueryRow(ctx,
		`UPDATE disputes SET status = 'resolved', resolution = $1, resolved_by = $2,
		    refund_amount = $3, resolved_at = $4
		 WHERE id = $5
		 RETURNING id, session_id, raised_by, against, reason, description,
		    status::text, resolution, resolved_by, refund_amount, created_at, resolved_at`,
		req.Resolution, aid, req.RefundAmount, now, did,
	).Scan(
		&d.ID, &d.SessionID, &d.RaisedByID, &d.AgainstID,
		&d.Reason, &d.Description, &d.Status, &d.Resolution,
		&d.ResolvedBy, &d.RefundAmount, &d.CreatedAt, &d.ResolvedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("resolve dispute: %w", err)
	}

	// Populate names
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, d.RaisedByID,
	).Scan(&d.RaisedByName)
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, d.AgainstID,
	).Scan(&d.AgainstName)

	return &d, nil
}

// ═══════════════════════════════════════════════════════════════
// Analytics
// ═══════════════════════════════════════════════════════════════

func (s *Service) AnalyticsOverview(ctx context.Context) (*AnalyticsOverview, error) {
	var a AnalyticsOverview

	err := s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM users WHERE is_active = true`,
	).Scan(&a.TotalUsers)
	if err != nil {
		return nil, fmt.Errorf("count users: %w", err)
	}

	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE role = 'teacher'`).Scan(&a.TotalTeachers)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE role = 'student'`).Scan(&a.TotalStudents)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE role = 'parent'`).Scan(&a.TotalParents)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM sessions`).Scan(&a.TotalSessions)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM courses`).Scan(&a.TotalCourses)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE status = 'completed'`).Scan(&a.TotalRevenue)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(commission), 0) FROM transactions WHERE status = 'completed'`).Scan(&a.TotalCommission)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM teacher_profiles WHERE verification_status = 'pending'`).Scan(&a.PendingVerify)
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM disputes WHERE status = 'open'`).Scan(&a.OpenDisputes)

	return &a, nil
}

func (s *Service) AnalyticsRevenue(ctx context.Context) (*RevenueAnalytics, error) {
	var r RevenueAnalytics

	err := s.db.Pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(amount), 0), COALESCE(SUM(commission), 0),
		    COALESCE(SUM(refund_amount), 0), COUNT(*)
		 FROM transactions WHERE status = 'completed'`,
	).Scan(&r.TotalRevenue, &r.TotalCommission, &r.TotalRefunds, &r.TransactionCount)
	if err != nil {
		return nil, fmt.Errorf("query revenue: %w", err)
	}

	rows, err := s.db.Pool.Query(ctx,
		`SELECT payment_method::text, COALESCE(SUM(amount), 0),
		    COALESCE(SUM(commission), 0), COUNT(*)
		 FROM transactions WHERE status = 'completed'
		 GROUP BY payment_method`,
	)
	if err != nil {
		return nil, fmt.Errorf("query revenue by method: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var m MethodRevenue
		if err := rows.Scan(&m.Method, &m.Amount, &m.Commission, &m.Count); err != nil {
			return nil, fmt.Errorf("scan method revenue: %w", err)
		}
		r.ByMethod = append(r.ByMethod, m)
	}

	if r.ByMethod == nil {
		r.ByMethod = []MethodRevenue{}
	}

	return &r, nil
}

// ═══════════════════════════════════════════════════════════════
// Config (Subjects & Levels)
// ═══════════════════════════════════════════════════════════════

type SubjectResponse struct {
	ID       uuid.UUID `json:"id"`
	NameFr   string    `json:"name"`
	NameAr   string    `json:"name_ar"`
	NameEn   string    `json:"name_en"`
	Category string    `json:"category"`
}

type LevelResponse struct {
	ID    uuid.UUID `json:"id"`
	Name  string    `json:"name"`
	Code  string    `json:"code"`
	Cycle string    `json:"cycle"`
	Order int       `json:"order"`
}

func (s *Service) UpdateSubjects(ctx context.Context, req UpdateSubjectsRequest) ([]SubjectResponse, error) {
	var result []SubjectResponse
	for _, sub := range req.Subjects {
		nameAr := sub.NameAr
		if nameAr == "" {
			nameAr = sub.NameFr
		}
		nameEn := sub.NameEn
		if nameEn == "" {
			nameEn = sub.NameFr
		}

		// Check if subject with same name_fr already exists
		var resp SubjectResponse
		err := s.db.Pool.QueryRow(ctx,
			`SELECT id, name_fr, name_ar, name_en, category::text FROM subjects WHERE name_fr = $1`,
			sub.NameFr,
		).Scan(&resp.ID, &resp.NameFr, &resp.NameAr, &resp.NameEn, &resp.Category)
		if err == nil {
			// Update existing
			_ = s.db.Pool.QueryRow(ctx,
				`UPDATE subjects SET name_ar = $1, name_en = $2, category = $3::subject_category
				 WHERE id = $4
				 RETURNING id, name_fr, name_ar, name_en, category::text`,
				nameAr, nameEn, sub.Category, resp.ID,
			).Scan(&resp.ID, &resp.NameFr, &resp.NameAr, &resp.NameEn, &resp.Category)
			result = append(result, resp)
			continue
		}

		// Insert new
		err = s.db.Pool.QueryRow(ctx,
			`INSERT INTO subjects (name_fr, name_ar, name_en, category)
			 VALUES ($1, $2, $3, $4::subject_category)
			 RETURNING id, name_fr, name_ar, name_en, category::text`,
			sub.NameFr, nameAr, nameEn, sub.Category,
		).Scan(&resp.ID, &resp.NameFr, &resp.NameAr, &resp.NameEn, &resp.Category)
		if err != nil {
			return nil, fmt.Errorf("insert subject %s: %w", sub.NameFr, err)
		}
		result = append(result, resp)
	}

	if result == nil {
		result = []SubjectResponse{}
	}

	return result, nil
}

func (s *Service) UpdateLevels(ctx context.Context, req UpdateLevelsRequest) ([]LevelResponse, error) {
	var result []LevelResponse
	for _, lvl := range req.Levels {
		var resp LevelResponse
		err := s.db.Pool.QueryRow(ctx,
			`INSERT INTO levels (name, code, cycle, "order")
			 VALUES ($1, $2, $3::education_cycle, $4)
			 ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, cycle = EXCLUDED.cycle, "order" = EXCLUDED."order"
			 RETURNING id, name, code, cycle::text, "order"`,
			lvl.Name, lvl.Code, lvl.Cycle, lvl.Order,
		).Scan(&resp.ID, &resp.Name, &resp.Code, &resp.Cycle, &resp.Order)
		if err != nil {
			return nil, fmt.Errorf("upsert level %s: %w", lvl.Name, err)
		}
		result = append(result, resp)
	}

	if result == nil {
		result = []LevelResponse{}
	}

	return result, nil
}
