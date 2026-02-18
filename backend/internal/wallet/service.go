package wallet

import (
	"context"
	"errors"
	"fmt"
	"math"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ═══════════════════════════════════════════════════════════════
// Errors
// ═══════════════════════════════════════════════════════════════

var (
	ErrWalletNotFound        = errors.New("wallet not found")
	ErrInsufficientBalance   = errors.New("insufficient wallet balance")
	ErrPackageNotFound       = errors.New("credit package not found")
	ErrPackageInactive       = errors.New("credit package is no longer available")
	ErrTransactionNotFound   = errors.New("wallet transaction not found")
	ErrAlreadyProcessed      = errors.New("transaction already processed")
	ErrNotPendingPurchase    = errors.New("only pending purchases can be approved")
	ErrRefundNotEligible     = errors.New("refund not eligible — first session already started")
	ErrEnrollmentNotAccepted = errors.New("enrollment is not in accepted state")
)

// ═══════════════════════════════════════════════════════════════
// Service
// ═══════════════════════════════════════════════════════════════

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ═══════════════════════════════════════════════════════════════
// Get or Create Wallet
// ═══════════════════════════════════════════════════════════════

// GetOrCreateWallet returns the teacher's wallet, creating it on first access.
func (s *Service) GetOrCreateWallet(ctx context.Context, teacherID string) (*WalletResponse, error) {
	tid, err := uuid.Parse(teacherID)
	if err != nil {
		return nil, ErrWalletNotFound
	}

	// Upsert wallet row (idempotent)
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO teacher_wallets (teacher_id)
		 VALUES ($1)
		 ON CONFLICT (teacher_id) DO NOTHING`, tid,
	)
	if err != nil {
		return nil, fmt.Errorf("upsert wallet: %w", err)
	}

	return s.getWalletByTeacher(ctx, tid)
}

// ═══════════════════════════════════════════════════════════════
// Buy Credits (teacher submits purchase — pending admin approval)
// ═══════════════════════════════════════════════════════════════

func (s *Service) BuyCredits(ctx context.Context, teacherID string, req BuyCreditsRequest) (*WalletTransactionResponse, error) {
	tid, _ := uuid.Parse(teacherID)

	// Validate package
	pkg, err := s.getPackage(ctx, req.PackageID)
	if err != nil {
		return nil, err
	}
	if !pkg.IsActive {
		return nil, ErrPackageInactive
	}

	// Ensure wallet exists
	wallet, err := s.GetOrCreateWallet(ctx, teacherID)
	if err != nil {
		return nil, err
	}

	txID := uuid.New()
	desc := fmt.Sprintf("Achat de crédits — Forfait %s (%0.f DA + %0.f DA bonus)", pkg.Name, pkg.Amount, pkg.Bonus)

	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO wallet_transactions
		    (id, wallet_id, type, status, amount, balance_after, description, package_id, payment_method, provider_ref)
		 VALUES ($1, $2, 'purchase', 'pending', $3, $4, $5, $6, $7, $8)`,
		txID, wallet.ID, pkg.TotalCredits, wallet.Balance, desc,
		req.PackageID, req.PaymentMethod, req.ProviderRef,
	)
	if err != nil {
		return nil, fmt.Errorf("insert purchase tx: %w", err)
	}

	// Auto-create wallet if teacher is new (upsert above handles it)
	_ = tid // used above

	return s.getTransaction(ctx, txID)
}

// ═══════════════════════════════════════════════════════════════
// Admin Approve / Reject Purchase
// ═══════════════════════════════════════════════════════════════

func (s *Service) AdminApprovePurchase(ctx context.Context, txID, adminID string, approved bool, notes string) (*WalletTransactionResponse, error) {
	tid, _ := uuid.Parse(txID)
	aid, _ := uuid.Parse(adminID)

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Lock the transaction row
	var walletID uuid.UUID
	var currentStatus string
	var amount float64
	err = tx.QueryRow(ctx,
		`SELECT wallet_id, status::text, amount FROM wallet_transactions WHERE id = $1 FOR UPDATE`, tid,
	).Scan(&walletID, &currentStatus, &amount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTransactionNotFound
		}
		return nil, fmt.Errorf("lock tx: %w", err)
	}
	if currentStatus != "pending" {
		return nil, ErrAlreadyProcessed
	}

	if approved {
		// Lock wallet and credit balance
		var currentBalance float64
		err = tx.QueryRow(ctx,
			`SELECT balance FROM teacher_wallets WHERE id = $1 FOR UPDATE`, walletID,
		).Scan(&currentBalance)
		if err != nil {
			return nil, fmt.Errorf("lock wallet: %w", err)
		}

		newBalance := currentBalance + amount
		_, err = tx.Exec(ctx,
			`UPDATE teacher_wallets
			 SET balance = $1, total_purchased = total_purchased + $2, updated_at = NOW()
			 WHERE id = $3`, newBalance, amount, walletID,
		)
		if err != nil {
			return nil, fmt.Errorf("credit wallet: %w", err)
		}

		_, err = tx.Exec(ctx,
			`UPDATE wallet_transactions
			 SET status = 'completed', balance_after = $1, admin_id = $2, admin_notes = $3
			 WHERE id = $4`, newBalance, aid, notes, tid,
		)
		if err != nil {
			return nil, fmt.Errorf("approve tx: %w", err)
		}
	} else {
		// Rejected
		_, err = tx.Exec(ctx,
			`UPDATE wallet_transactions
			 SET status = 'failed', admin_id = $1, admin_notes = $2
			 WHERE id = $3`, aid, notes, tid,
		)
		if err != nil {
			return nil, fmt.Errorf("reject tx: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return s.getTransaction(ctx, tid)
}

// ═══════════════════════════════════════════════════════════════
// Deduct Star (called when enrollment is accepted)
// ═══════════════════════════════════════════════════════════════

// DeductStar deducts 1 star cost from the teacher's wallet.
// Called inside a DB transaction from the enrollment accept flow.
// Returns the wallet_transaction ID for reference.
func (s *Service) DeductStar(ctx context.Context, teacherID string, sessionType string, enrollmentID, seriesID uuid.UUID, studentName, seriesTitle string) (uuid.UUID, error) {
	tid, _ := uuid.Parse(teacherID)
	cost := StarCost(sessionType)

	dbtx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return uuid.Nil, fmt.Errorf("begin tx: %w", err)
	}
	defer dbtx.Rollback(ctx)

	// Lock wallet
	var walletID uuid.UUID
	var balance float64
	err = dbtx.QueryRow(ctx,
		`SELECT id, balance FROM teacher_wallets WHERE teacher_id = $1 FOR UPDATE`, tid,
	).Scan(&walletID, &balance)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, ErrInsufficientBalance // no wallet = no balance
		}
		return uuid.Nil, fmt.Errorf("lock wallet: %w", err)
	}

	if balance < cost {
		return uuid.Nil, ErrInsufficientBalance
	}

	newBalance := balance - cost

	_, err = dbtx.Exec(ctx,
		`UPDATE teacher_wallets
		 SET balance = $1, total_spent = total_spent + $2, updated_at = NOW()
		 WHERE id = $3`, newBalance, cost, walletID,
	)
	if err != nil {
		return uuid.Nil, fmt.Errorf("deduct wallet: %w", err)
	}

	starLabel := "★ Groupe"
	if sessionType == "one_on_one" {
		starLabel = "★ Privé"
	}
	desc := fmt.Sprintf("%s — %s pour %s", starLabel, seriesTitle, studentName)

	txID := uuid.New()
	_, err = dbtx.Exec(ctx,
		`INSERT INTO wallet_transactions
		    (id, wallet_id, type, status, amount, balance_after, description, enrollment_id, series_id)
		 VALUES ($1, $2, 'star_deduction', 'completed', $3, $4, $5, $6, $7)`,
		txID, walletID, cost, newBalance, desc, enrollmentID, seriesID,
	)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert deduction tx: %w", err)
	}

	if err := dbtx.Commit(ctx); err != nil {
		return uuid.Nil, fmt.Errorf("commit: %w", err)
	}

	return txID, nil
}

// ═══════════════════════════════════════════════════════════════
// Refund Star (called when student removed BEFORE first session)
// ═══════════════════════════════════════════════════════════════

// RefundStar adds back the star cost to the teacher's wallet.
// Only allowed if no session in the series has started yet.
func (s *Service) RefundStar(ctx context.Context, teacherID string, enrollmentID uuid.UUID) error {
	tid, _ := uuid.Parse(teacherID)

	// Find the original star_deduction for this enrollment
	var originalAmount float64
	var walletID uuid.UUID
	var seriesID uuid.UUID
	var seriesTitle string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT wt.amount, wt.wallet_id, wt.series_id, COALESCE(ss.title,'')
		 FROM wallet_transactions wt
		 LEFT JOIN session_series ss ON ss.id = wt.series_id
		 WHERE wt.enrollment_id = $1 AND wt.type = 'star_deduction' AND wt.status = 'completed'
		 LIMIT 1`,
		enrollmentID,
	).Scan(&originalAmount, &walletID, &seriesID, &seriesTitle)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil // No deduction to refund (e.g., legacy enrollment)
		}
		return fmt.Errorf("find deduction: %w", err)
	}

	// Check if any session in the series has already started
	var startedCount int
	err = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sessions
		 WHERE series_id = $1 AND (status = 'live' OR status = 'completed' OR actual_start IS NOT NULL)`,
		seriesID,
	).Scan(&startedCount)
	if err != nil {
		return fmt.Errorf("check sessions: %w", err)
	}
	if startedCount > 0 {
		return ErrRefundNotEligible
	}

	// Check we haven't already refunded this enrollment
	var existingRefund int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM wallet_transactions WHERE enrollment_id = $1 AND type = 'refund'`,
		enrollmentID,
	).Scan(&existingRefund)
	if existingRefund > 0 {
		return nil // Already refunded, idempotent
	}

	// Apply refund in a transaction
	dbtx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer dbtx.Rollback(ctx)

	// Lock wallet
	var balance float64
	err = dbtx.QueryRow(ctx,
		`SELECT balance FROM teacher_wallets WHERE id = $1 AND teacher_id = $2 FOR UPDATE`, walletID, tid,
	).Scan(&balance)
	if err != nil {
		return fmt.Errorf("lock wallet: %w", err)
	}

	newBalance := balance + originalAmount
	_, err = dbtx.Exec(ctx,
		`UPDATE teacher_wallets
		 SET balance = $1, total_refunded = total_refunded + $2, updated_at = NOW()
		 WHERE id = $3`, newBalance, originalAmount, walletID,
	)
	if err != nil {
		return fmt.Errorf("refund wallet: %w", err)
	}

	desc := fmt.Sprintf("★ Remboursement — %s", seriesTitle)
	txID := uuid.New()
	_, err = dbtx.Exec(ctx,
		`INSERT INTO wallet_transactions
		    (id, wallet_id, type, status, amount, balance_after, description, enrollment_id, series_id)
		 VALUES ($1, $2, 'refund', 'completed', $3, $4, $5, $6, $7)`,
		txID, walletID, originalAmount, newBalance, desc, enrollmentID, seriesID,
	)
	if err != nil {
		return fmt.Errorf("insert refund tx: %w", err)
	}

	if err := dbtx.Commit(ctx); err != nil {
		return fmt.Errorf("commit: %w", err)
	}

	return nil
}

// ═══════════════════════════════════════════════════════════════
// List Transactions
// ═══════════════════════════════════════════════════════════════

func (s *Service) ListTransactions(ctx context.Context, teacherID string, txType string, page, limit int) ([]WalletTransactionResponse, int64, error) {
	tid, _ := uuid.Parse(teacherID)
	offset := (page - 1) * limit

	// Get wallet ID
	var walletID uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT id FROM teacher_wallets WHERE teacher_id = $1`, tid,
	).Scan(&walletID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return []WalletTransactionResponse{}, 0, nil
		}
		return nil, 0, fmt.Errorf("get wallet: %w", err)
	}

	// Count
	countQ := `SELECT COUNT(*) FROM wallet_transactions WHERE wallet_id = $1`
	countArgs := []interface{}{walletID}
	if txType != "" {
		countQ += ` AND type = $2::wallet_tx_type`
		countArgs = append(countArgs, txType)
	}
	var total int64
	_ = s.db.Pool.QueryRow(ctx, countQ, countArgs...).Scan(&total)

	// Fetch
	listQ := `SELECT wt.id, wt.wallet_id, wt.type::text, wt.status::text, wt.amount, wt.balance_after,
	                  wt.description, wt.package_id, COALESCE(cp.name,''), COALESCE(wt.payment_method,''),
	                  COALESCE(wt.provider_ref,''), wt.enrollment_id, wt.series_id,
	                  COALESCE(ss.title,''), COALESCE(wt.admin_notes,''), wt.created_at
	           FROM wallet_transactions wt
	           LEFT JOIN credit_packages cp ON cp.id = wt.package_id
	           LEFT JOIN session_series ss ON ss.id = wt.series_id
	           WHERE wt.wallet_id = $1`
	listArgs := []interface{}{walletID}
	if txType != "" {
		listQ += ` AND wt.type = $2::wallet_tx_type`
		listArgs = append(listArgs, txType)
	}
	listQ += fmt.Sprintf(` ORDER BY wt.created_at DESC LIMIT %d OFFSET %d`, limit, offset)

	rows, err := s.db.Pool.Query(ctx, listQ, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("list tx: %w", err)
	}
	defer rows.Close()

	var results []WalletTransactionResponse
	for rows.Next() {
		var t WalletTransactionResponse
		if err := rows.Scan(
			&t.ID, &t.WalletID, &t.Type, &t.Status, &t.Amount, &t.BalanceAfter,
			&t.Description, &t.PackageID, &t.PackageName, &t.PaymentMethod,
			&t.ProviderRef, &t.EnrollmentID, &t.SeriesID,
			&t.SeriesTitle, &t.AdminNotes, &t.CreatedAt,
		); err != nil {
			continue
		}
		results = append(results, t)
	}
	if results == nil {
		results = []WalletTransactionResponse{}
	}

	return results, total, nil
}

// ═══════════════════════════════════════════════════════════════
// List Packages
// ═══════════════════════════════════════════════════════════════

func (s *Service) ListPackages(ctx context.Context) ([]CreditPackageResponse, error) {
	rows, err := s.db.Pool.Query(ctx,
		`SELECT id, name, amount, bonus, total_credits, is_active, sort_order
		 FROM credit_packages WHERE is_active = true ORDER BY sort_order`,
	)
	if err != nil {
		return nil, fmt.Errorf("list packages: %w", err)
	}
	defer rows.Close()

	var pkgs []CreditPackageResponse
	for rows.Next() {
		var p CreditPackageResponse
		if err := rows.Scan(&p.ID, &p.Name, &p.Amount, &p.Bonus, &p.TotalCredits, &p.IsActive, &p.SortOrder); err != nil {
			continue
		}
		p.GroupStars = int(math.Floor(p.TotalCredits / GroupStarCost))
		p.PrivateStars = int(math.Floor(p.TotalCredits / PrivateStarCost))
		pkgs = append(pkgs, p)
	}
	if pkgs == nil {
		pkgs = []CreditPackageResponse{}
	}
	return pkgs, nil
}

// ═══════════════════════════════════════════════════════════════
// Admin: List Pending Purchases
// ═══════════════════════════════════════════════════════════════

func (s *Service) AdminListPendingPurchases(ctx context.Context, page, limit int) ([]WalletTransactionResponse, int64, error) {
	offset := (page - 1) * limit

	var total int64
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM wallet_transactions WHERE type = 'purchase' AND status = 'pending'`,
	).Scan(&total)

	rows, err := s.db.Pool.Query(ctx,
		fmt.Sprintf(`SELECT wt.id, wt.wallet_id, wt.type::text, wt.status::text, wt.amount, wt.balance_after,
		                    wt.description, wt.package_id, COALESCE(cp.name,''), COALESCE(wt.payment_method,''),
		                    COALESCE(wt.provider_ref,''), wt.enrollment_id, wt.series_id,
		                    COALESCE(ss.title,''), COALESCE(wt.admin_notes,''), wt.created_at
		             FROM wallet_transactions wt
		             LEFT JOIN credit_packages cp ON cp.id = wt.package_id
		             LEFT JOIN session_series ss ON ss.id = wt.series_id
		             WHERE wt.type = 'purchase' AND wt.status = 'pending'
		             ORDER BY wt.created_at ASC
		             LIMIT %d OFFSET %d`, limit, offset),
	)
	if err != nil {
		return nil, 0, fmt.Errorf("admin list: %w", err)
	}
	defer rows.Close()

	var results []WalletTransactionResponse
	for rows.Next() {
		var t WalletTransactionResponse
		if err := rows.Scan(
			&t.ID, &t.WalletID, &t.Type, &t.Status, &t.Amount, &t.BalanceAfter,
			&t.Description, &t.PackageID, &t.PackageName, &t.PaymentMethod,
			&t.ProviderRef, &t.EnrollmentID, &t.SeriesID,
			&t.SeriesTitle, &t.AdminNotes, &t.CreatedAt,
		); err != nil {
			continue
		}
		results = append(results, t)
	}
	if results == nil {
		results = []WalletTransactionResponse{}
	}
	return results, total, nil
}

// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

func (s *Service) getWalletByTeacher(ctx context.Context, teacherID uuid.UUID) (*WalletResponse, error) {
	var w WalletResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT id, teacher_id, balance, total_purchased, total_spent, total_refunded, created_at, updated_at
		 FROM teacher_wallets WHERE teacher_id = $1`, teacherID,
	).Scan(&w.ID, &w.TeacherID, &w.Balance, &w.TotalPurchased, &w.TotalSpent, &w.TotalRefunded, &w.CreatedAt, &w.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrWalletNotFound
		}
		return nil, fmt.Errorf("get wallet: %w", err)
	}
	w.GroupStarsAvailable = int(math.Floor(w.Balance / GroupStarCost))
	w.PrivateStarsAvailable = int(math.Floor(w.Balance / PrivateStarCost))
	return &w, nil
}

func (s *Service) getPackage(ctx context.Context, pkgID uuid.UUID) (*CreditPackageResponse, error) {
	var p CreditPackageResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT id, name, amount, bonus, total_credits, is_active, sort_order
		 FROM credit_packages WHERE id = $1`, pkgID,
	).Scan(&p.ID, &p.Name, &p.Amount, &p.Bonus, &p.TotalCredits, &p.IsActive, &p.SortOrder)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrPackageNotFound
		}
		return nil, fmt.Errorf("get package: %w", err)
	}
	p.GroupStars = int(math.Floor(p.TotalCredits / GroupStarCost))
	p.PrivateStars = int(math.Floor(p.TotalCredits / PrivateStarCost))
	return &p, nil
}

func (s *Service) getTransaction(ctx context.Context, txID uuid.UUID) (*WalletTransactionResponse, error) {
	var t WalletTransactionResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT wt.id, wt.wallet_id, wt.type::text, wt.status::text, wt.amount, wt.balance_after,
		        wt.description, wt.package_id, COALESCE(cp.name,''), COALESCE(wt.payment_method,''),
		        COALESCE(wt.provider_ref,''), wt.enrollment_id, wt.series_id,
		        COALESCE(ss.title,''), COALESCE(wt.admin_notes,''), wt.created_at
		 FROM wallet_transactions wt
		 LEFT JOIN credit_packages cp ON cp.id = wt.package_id
		 LEFT JOIN session_series ss ON ss.id = wt.series_id
		 WHERE wt.id = $1`, txID,
	).Scan(
		&t.ID, &t.WalletID, &t.Type, &t.Status, &t.Amount, &t.BalanceAfter,
		&t.Description, &t.PackageID, &t.PackageName, &t.PaymentMethod,
		&t.ProviderRef, &t.EnrollmentID, &t.SeriesID,
		&t.SeriesTitle, &t.AdminNotes, &t.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTransactionNotFound
		}
		return nil, fmt.Errorf("get tx: %w", err)
	}
	return &t, nil
}
