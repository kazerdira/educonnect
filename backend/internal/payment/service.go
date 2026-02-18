package payment

import (
	"context"
	"errors"
	"fmt"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const commissionRate = 0.15 // 15% platform commission

var (
	ErrTransactionNotFound  = errors.New("transaction not found")
	ErrSubscriptionNotFound = errors.New("subscription not found")
	ErrNotAuthorized        = errors.New("not authorized")
	ErrAlreadyCancelled     = errors.New("subscription already cancelled")
	ErrInvalidRefund        = errors.New("refund amount exceeds transaction amount")
	ErrAlreadyRefunded      = errors.New("transaction already refunded")
	ErrNotPending           = errors.New("transaction is not in pending status")
	ErrNotCompleted         = errors.New("only completed transactions can be refunded")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ─── InitiatePayment ────────────────────────────────────────────

func (s *Service) InitiatePayment(ctx context.Context, payerID string, req InitiatePaymentRequest) (*TransactionResponse, error) {
	uid, _ := uuid.Parse(payerID)

	commission := req.Amount * commissionRate
	netAmount := req.Amount - commission

	var t TransactionResponse
	err := s.db.Pool.QueryRow(ctx,
		`INSERT INTO transactions (payer_id, payee_id, session_id, course_id,
		    amount, commission, net_amount, payment_method, description, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8::payment_method,$9,'pending')
		 RETURNING id, payer_id, payee_id, session_id, course_id, subscription_id,
		    amount, commission, net_amount, payment_method::text, status::text,
		    provider_reference, description, refund_amount, refund_reason,
		    created_at, updated_at`,
		uid, req.PayeeID, req.SessionID, req.CourseID,
		req.Amount, commission, netAmount, req.PaymentMethod, req.Description,
	).Scan(
		&t.ID, &t.PayerID, &t.PayeeID, &t.SessionID, &t.CourseID, &t.SubscriptionID,
		&t.Amount, &t.Commission, &t.NetAmount, &t.PaymentMethod, &t.Status,
		&t.ProviderReference, &t.Description, &t.RefundAmount, &t.RefundReason,
		&t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("insert transaction: %w", err)
	}

	s.populateNames(ctx, &t)
	return &t, nil
}

// ─── ConfirmPayment ─────────────────────────────────────────────

func (s *Service) ConfirmPayment(ctx context.Context, userID string, req ConfirmPaymentRequest) (*TransactionResponse, error) {
	// Verify payer owns this transaction and status is pending
	var dbPayerID uuid.UUID
	var currentStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT payer_id, status::text FROM transactions WHERE id = $1`, req.TransactionID,
	).Scan(&dbPayerID, &currentStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTransactionNotFound
		}
		return nil, fmt.Errorf("query transaction: %w", err)
	}
	if dbPayerID.String() != userID {
		return nil, ErrNotAuthorized
	}
	if currentStatus != "pending" {
		return nil, ErrNotPending
	}

	var t TransactionResponse
	err = s.db.Pool.QueryRow(ctx,
		`UPDATE transactions SET status = 'completed', provider_reference = $1
		 WHERE id = $2
		 RETURNING id, payer_id, payee_id, session_id, course_id, subscription_id,
		    amount, commission, net_amount, payment_method::text, status::text,
		    provider_reference, description, refund_amount, refund_reason,
		    created_at, updated_at`,
		req.ProviderReference, req.TransactionID,
	).Scan(
		&t.ID, &t.PayerID, &t.PayeeID, &t.SessionID, &t.CourseID, &t.SubscriptionID,
		&t.Amount, &t.Commission, &t.NetAmount, &t.PaymentMethod, &t.Status,
		&t.ProviderReference, &t.Description, &t.RefundAmount, &t.RefundReason,
		&t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update transaction: %w", err)
	}

	s.populateNames(ctx, &t)
	return &t, nil
}

// ─── PaymentHistory ─────────────────────────────────────────────

func (s *Service) PaymentHistory(ctx context.Context, userID string, limit, offset int) ([]TransactionResponse, int, error) {
	uid, _ := uuid.Parse(userID)

	var total int
	err := s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM transactions WHERE payer_id = $1 OR payee_id = $1`, uid,
	).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("count transactions: %w", err)
	}

	rows, err := s.db.Pool.Query(ctx,
		`SELECT t.id, t.payer_id, t.payee_id, t.session_id, t.course_id, t.subscription_id,
		    t.amount, t.commission, t.net_amount, t.payment_method::text, t.status::text,
		    t.provider_reference, t.description, t.refund_amount, t.refund_reason,
		    t.created_at, t.updated_at,
		    payer.first_name || ' ' || payer.last_name,
		    payee.first_name || ' ' || payee.last_name
		 FROM transactions t
		 JOIN users payer ON payer.id = t.payer_id
		 JOIN users payee ON payee.id = t.payee_id
		 WHERE t.payer_id = $1 OR t.payee_id = $1
		 ORDER BY t.created_at DESC
		 LIMIT $2 OFFSET $3`, uid, limit, offset,
	)
	if err != nil {
		return nil, 0, fmt.Errorf("query transactions: %w", err)
	}
	defer rows.Close()

	var transactions []TransactionResponse
	for rows.Next() {
		var t TransactionResponse
		if err := rows.Scan(
			&t.ID, &t.PayerID, &t.PayeeID, &t.SessionID, &t.CourseID, &t.SubscriptionID,
			&t.Amount, &t.Commission, &t.NetAmount, &t.PaymentMethod, &t.Status,
			&t.ProviderReference, &t.Description, &t.RefundAmount, &t.RefundReason,
			&t.CreatedAt, &t.UpdatedAt,
			&t.PayerName, &t.PayeeName,
		); err != nil {
			return nil, 0, fmt.Errorf("scan transaction: %w", err)
		}
		transactions = append(transactions, t)
	}

	if transactions == nil {
		transactions = []TransactionResponse{}
	}

	return transactions, total, nil
}

// ─── RefundPayment ──────────────────────────────────────────────

func (s *Service) RefundPayment(ctx context.Context, userID string, req RefundPaymentRequest) (*TransactionResponse, error) {
	// Verify ownership
	var dbPayerID uuid.UUID
	var currentStatus string
	var currentAmount float64
	err := s.db.Pool.QueryRow(ctx,
		`SELECT payer_id, status::text, amount FROM transactions WHERE id = $1`, req.TransactionID,
	).Scan(&dbPayerID, &currentStatus, &currentAmount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTransactionNotFound
		}
		return nil, fmt.Errorf("query transaction: %w", err)
	}
	if dbPayerID.String() != userID {
		return nil, ErrNotAuthorized
	}
	if currentStatus == "refunded" {
		return nil, ErrAlreadyRefunded
	}
	if currentStatus != "completed" {
		return nil, ErrNotCompleted
	}
	if req.Amount > currentAmount {
		return nil, ErrInvalidRefund
	}

	var t TransactionResponse
	err = s.db.Pool.QueryRow(ctx,
		`UPDATE transactions SET status = 'refunded', refund_amount = $1, refund_reason = $2
		 WHERE id = $3
		 RETURNING id, payer_id, payee_id, session_id, course_id, subscription_id,
		    amount, commission, net_amount, payment_method::text, status::text,
		    provider_reference, description, refund_amount, refund_reason,
		    created_at, updated_at`,
		req.Amount, req.Reason, req.TransactionID,
	).Scan(
		&t.ID, &t.PayerID, &t.PayeeID, &t.SessionID, &t.CourseID, &t.SubscriptionID,
		&t.Amount, &t.Commission, &t.NetAmount, &t.PaymentMethod, &t.Status,
		&t.ProviderReference, &t.Description, &t.RefundAmount, &t.RefundReason,
		&t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update transaction: %w", err)
	}

	s.populateNames(ctx, &t)
	return &t, nil
}

// ─── CreateSubscription ─────────────────────────────────────────

func (s *Service) CreateSubscription(ctx context.Context, studentID string, req CreateSubscriptionRequest) (*SubscriptionResponse, error) {
	uid, _ := uuid.Parse(studentID)

	autoRenew := true
	if req.AutoRenew != nil {
		autoRenew = *req.AutoRenew
	}

	var sub SubscriptionResponse
	err := s.db.Pool.QueryRow(ctx,
		`INSERT INTO subscriptions (student_id, teacher_id, plan_type, sessions_per_month, price, start_date, end_date, auto_renew)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 RETURNING id, student_id, teacher_id, plan_type, sessions_per_month, sessions_used,
		    price, status::text, start_date::text, end_date::text, auto_renew, created_at, updated_at`,
		uid, req.TeacherID, req.PlanType, req.SessionsPerMonth, req.Price,
		req.StartDate, req.EndDate, autoRenew,
	).Scan(
		&sub.ID, &sub.StudentID, &sub.TeacherID, &sub.PlanType, &sub.SessionsPerMonth,
		&sub.SessionsUsed, &sub.Price, &sub.Status, &sub.StartDate, &sub.EndDate,
		&sub.AutoRenew, &sub.CreatedAt, &sub.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("insert subscription: %w", err)
	}

	s.populateSubNames(ctx, &sub)
	return &sub, nil
}

// ─── ListSubscriptions ──────────────────────────────────────────

func (s *Service) ListSubscriptions(ctx context.Context, userID string, role string) ([]SubscriptionResponse, error) {
	uid, _ := uuid.Parse(userID)

	var whereClause string
	if role == "teacher" {
		whereClause = "s.teacher_id = $1"
	} else {
		whereClause = "s.student_id = $1"
	}

	rows, err := s.db.Pool.Query(ctx,
		fmt.Sprintf(`SELECT s.id, s.student_id, s.teacher_id, s.plan_type, s.sessions_per_month,
		    s.sessions_used, s.price, s.status::text, s.start_date::text, s.end_date::text,
		    s.auto_renew, s.created_at, s.updated_at,
		    u.first_name || ' ' || u.last_name AS teacher_name
		 FROM subscriptions s
		 JOIN users u ON u.id = s.teacher_id
		 WHERE %s
		 ORDER BY s.created_at DESC`, whereClause), uid,
	)
	if err != nil {
		return nil, fmt.Errorf("query subscriptions: %w", err)
	}
	defer rows.Close()

	var subs []SubscriptionResponse
	for rows.Next() {
		var sub SubscriptionResponse
		if err := rows.Scan(
			&sub.ID, &sub.StudentID, &sub.TeacherID, &sub.PlanType, &sub.SessionsPerMonth,
			&sub.SessionsUsed, &sub.Price, &sub.Status, &sub.StartDate, &sub.EndDate,
			&sub.AutoRenew, &sub.CreatedAt, &sub.UpdatedAt, &sub.TeacherName,
		); err != nil {
			return nil, fmt.Errorf("scan subscription: %w", err)
		}
		subs = append(subs, sub)
	}

	if subs == nil {
		subs = []SubscriptionResponse{}
	}

	return subs, nil
}

// ─── CancelSubscription ─────────────────────────────────────────

func (s *Service) CancelSubscription(ctx context.Context, userID string, subID string) error {
	uid, _ := uuid.Parse(userID)
	sid, _ := uuid.Parse(subID)

	var dbStudentID uuid.UUID
	var status string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT student_id, status::text FROM subscriptions WHERE id = $1`, sid,
	).Scan(&dbStudentID, &status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrSubscriptionNotFound
		}
		return fmt.Errorf("query subscription: %w", err)
	}
	if dbStudentID != uid {
		return ErrNotAuthorized
	}
	if status == "cancelled" {
		return ErrAlreadyCancelled
	}

	_, err = s.db.Pool.Exec(ctx,
		`UPDATE subscriptions SET status = 'cancelled' WHERE id = $1`, sid,
	)
	if err != nil {
		return fmt.Errorf("cancel subscription: %w", err)
	}

	return nil
}

// ─── Helpers ────────────────────────────────────────────────────

func (s *Service) populateNames(ctx context.Context, t *TransactionResponse) {
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, t.PayerID,
	).Scan(&t.PayerName)
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, t.PayeeID,
	).Scan(&t.PayeeName)
}

func (s *Service) populateSubNames(ctx context.Context, sub *SubscriptionResponse) {
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, sub.TeacherID,
	).Scan(&sub.TeacherName)
}
