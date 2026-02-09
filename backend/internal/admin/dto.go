package admin

import (
	"time"

	"github.com/google/uuid"
)

// ─── Users ──────────────────────────────────────────────────────

type AdminUserResponse struct {
	ID                 uuid.UUID `json:"id"`
	Email              *string   `json:"email,omitempty"`
	Phone              *string   `json:"phone,omitempty"`
	Role               string    `json:"role"`
	FirstName          string    `json:"first_name"`
	LastName           string    `json:"last_name"`
	AvatarURL          *string   `json:"avatar_url,omitempty"`
	IsActive           bool      `json:"is_active"`
	IsEmailVerified    bool      `json:"is_email_verified"`
	VerificationStatus *string   `json:"verification_status,omitempty"` // teacher only
	CreatedAt          time.Time `json:"created_at"`
}

type SuspendUserRequest struct {
	Reason string `json:"reason" validate:"required"`
}

// ─── Verifications ──────────────────────────────────────────────

type VerificationResponse struct {
	ID                 uuid.UUID `json:"id"`
	UserID             uuid.UUID `json:"user_id,omitempty"`
	Email              *string   `json:"email,omitempty"`
	FirstName          string    `json:"first_name"`
	LastName           string    `json:"last_name"`
	VerificationStatus string    `json:"verification_status"`
	Bio                *string   `json:"bio,omitempty"`
	Experience         *int      `json:"experience_years,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
}

type RejectVerificationRequest struct {
	Reason string `json:"reason" validate:"required"`
}

// ─── Disputes ───────────────────────────────────────────────────

type DisputeResponse struct {
	ID           uuid.UUID  `json:"id"`
	SessionID    uuid.UUID  `json:"session_id"`
	RaisedByID   uuid.UUID  `json:"raised_by"`
	RaisedByName string     `json:"raised_by_name,omitempty"`
	AgainstID    uuid.UUID  `json:"against"`
	AgainstName  string     `json:"against_name,omitempty"`
	Reason       string     `json:"reason"`
	Description  *string    `json:"description,omitempty"`
	Status       string     `json:"status"`
	Resolution   *string    `json:"resolution,omitempty"`
	ResolvedBy   *uuid.UUID `json:"resolved_by,omitempty"`
	RefundAmount float64    `json:"refund_amount"`
	CreatedAt    time.Time  `json:"created_at"`
	ResolvedAt   *time.Time `json:"resolved_at,omitempty"`
}

type ResolveDisputeRequest struct {
	Resolution   string  `json:"resolution" validate:"required"`
	RefundAmount float64 `json:"refund_amount"`
}

// ─── Analytics ──────────────────────────────────────────────────

type AnalyticsOverview struct {
	TotalUsers      int     `json:"total_users"`
	TotalTeachers   int     `json:"total_teachers"`
	TotalStudents   int     `json:"total_students"`
	TotalParents    int     `json:"total_parents"`
	TotalSessions   int     `json:"total_sessions"`
	TotalCourses    int     `json:"total_courses"`
	TotalRevenue    float64 `json:"total_revenue"`
	TotalCommission float64 `json:"total_commission"`
	PendingVerify   int     `json:"pending_verifications"`
	OpenDisputes    int     `json:"open_disputes"`
}

type RevenueAnalytics struct {
	TotalRevenue     float64         `json:"total_revenue"`
	TotalCommission  float64         `json:"total_commission"`
	TotalRefunds     float64         `json:"total_refunds"`
	TransactionCount int             `json:"transaction_count"`
	ByMethod         []MethodRevenue `json:"by_method"`
}

type MethodRevenue struct {
	Method     string  `json:"method"`
	Amount     float64 `json:"amount"`
	Commission float64 `json:"commission"`
	Count      int     `json:"count"`
}

// ─── Config ─────────────────────────────────────────────────────

type UpdateSubjectsRequest struct {
	Subjects []SubjectInput `json:"subjects" validate:"required,dive"`
}

type SubjectInput struct {
	NameFr   string `json:"name" validate:"required"`
	NameAr   string `json:"name_ar"`
	NameEn   string `json:"name_en"`
	Category string `json:"category" validate:"required"`
}

type UpdateLevelsRequest struct {
	Levels []LevelInput `json:"levels" validate:"required,dive"`
}

type LevelInput struct {
	Name  string `json:"name" validate:"required"`
	Code  string `json:"code" validate:"required"`
	Cycle string `json:"cycle" validate:"required"`
	Order int    `json:"order" validate:"required,min=1,max=12"`
}
