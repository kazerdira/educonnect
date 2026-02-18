package wallet

import (
	"time"

	"github.com/google/uuid"
)

// ═══════════════════════════════════════════════════════════════
// Star Pricing Constants
// ═══════════════════════════════════════════════════════════════
// Replaces the old per-hour platform_fees model.
// Cost is per enrollment (1 star per accepted student).

const (
	GroupStarCost   = 50.0 // DZD per enrollment in a group series
	PrivateStarCost = 70.0 // DZD per enrollment in a 1-on-1 series
)

// StarCost returns the DZD cost of one star based on session type.
func StarCost(sessionType string) float64 {
	if sessionType == "one_on_one" {
		return PrivateStarCost
	}
	return GroupStarCost
}

// ═══════════════════════════════════════════════════════════════
// Wallet Responses
// ═══════════════════════════════════════════════════════════════

type WalletResponse struct {
	ID             uuid.UUID `json:"id"`
	TeacherID      uuid.UUID `json:"teacher_id"`
	Balance        float64   `json:"balance"`
	TotalPurchased float64   `json:"total_purchased"`
	TotalSpent     float64   `json:"total_spent"`
	TotalRefunded  float64   `json:"total_refunded"`
	// Convenience: how many stars the balance can buy at each tier
	GroupStarsAvailable   int       `json:"group_stars_available"`
	PrivateStarsAvailable int       `json:"private_stars_available"`
	CreatedAt             time.Time `json:"created_at"`
	UpdatedAt             time.Time `json:"updated_at"`
}

type WalletTransactionResponse struct {
	ID            uuid.UUID  `json:"id"`
	WalletID      uuid.UUID  `json:"wallet_id"`
	Type          string     `json:"type"`   // purchase, star_deduction, refund
	Status        string     `json:"status"` // pending, completed, failed
	Amount        float64    `json:"amount"`
	BalanceAfter  float64    `json:"balance_after"`
	Description   string     `json:"description"`
	PackageID     *uuid.UUID `json:"package_id,omitempty"`
	PackageName   string     `json:"package_name,omitempty"`
	PaymentMethod string     `json:"payment_method,omitempty"`
	ProviderRef   string     `json:"provider_ref,omitempty"`
	EnrollmentID  *uuid.UUID `json:"enrollment_id,omitempty"`
	SeriesID      *uuid.UUID `json:"series_id,omitempty"`
	SeriesTitle   string     `json:"series_title,omitempty"`
	AdminNotes    string     `json:"admin_notes,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
}

type CreditPackageResponse struct {
	ID           uuid.UUID `json:"id"`
	Name         string    `json:"name"`
	Amount       float64   `json:"amount"`        // DZD price
	Bonus        float64   `json:"bonus"`         // bonus credits
	TotalCredits float64   `json:"total_credits"` // amount + bonus
	// Convenience: stars you get
	GroupStars   int  `json:"group_stars"`
	PrivateStars int  `json:"private_stars"`
	IsActive     bool `json:"is_active"`
	SortOrder    int  `json:"sort_order"`
}

// ═══════════════════════════════════════════════════════════════
// Requests
// ═══════════════════════════════════════════════════════════════

type BuyCreditsRequest struct {
	PackageID     uuid.UUID `json:"package_id" validate:"required"`
	PaymentMethod string    `json:"payment_method" validate:"required,oneof=ccp_baridimob edahabia"`
	ProviderRef   string    `json:"provider_ref" validate:"required"` // BaridiMob receipt ref
}

type AdminApprovePurchaseRequest struct {
	Approved bool   `json:"approved"`
	Notes    string `json:"notes"`
}

// ═══════════════════════════════════════════════════════════════
// Pagination
// ═══════════════════════════════════════════════════════════════

type PaginatedTransactions struct {
	Data []WalletTransactionResponse `json:"data"`
	Meta PaginationMeta              `json:"meta"`
}

type PaginationMeta struct {
	Page    int   `json:"page"`
	Limit   int   `json:"limit"`
	Total   int64 `json:"total"`
	HasMore bool  `json:"has_more"`
}
