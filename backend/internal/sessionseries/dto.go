package sessionseries

import (
	"time"

	"github.com/google/uuid"
)

// ═══════════════════════════════════════════════════════════════
// Platform Fee Constants
// Teacher pays ALL fees - students pay nothing to platform
// ═══════════════════════════════════════════════════════════════

const (
	GroupFeePerHourPerStudent = 50.0  // DA per student per hour
	IndividualFeePerHour      = 120.0 // DA per hour (no per-student)
)

// ═══════════════════════════════════════════════════════════════
// Session Series DTOs
// ═══════════════════════════════════════════════════════════════

type SeriesResponse struct {
	ID            uuid.UUID         `json:"id"`
	TeacherID     uuid.UUID         `json:"teacher_id"`
	TeacherName   string            `json:"teacher_name"`
	OfferingID    *uuid.UUID        `json:"offering_id,omitempty"`
	Title         string            `json:"title"`
	Description   string            `json:"description,omitempty"`
	SessionType   string            `json:"session_type"` // "one_on_one" or "group"
	DurationHours float64           `json:"duration_hours"`
	MinStudents   int               `json:"min_students"`
	MaxStudents   int               `json:"max_students"`
	PricePerHour  float64           `json:"price_per_hour"`
	TotalSessions int               `json:"total_sessions"`
	Status        string            `json:"status"`
	IsFinalized   bool              `json:"is_finalized"`
	FinalizedAt   *time.Time        `json:"finalized_at,omitempty"`
	Sessions      []SessionBrief    `json:"sessions,omitempty"`
	Enrollments   []EnrollmentBrief `json:"enrollments,omitempty"`
	EnrolledCount int               `json:"enrolled_count"` // Accepted enrollments
	PendingCount  int               `json:"pending_count"`  // Invited/Requested
	EstimatedFee  float64           `json:"estimated_fee"`  // Calculated platform fee
	FeePaid       bool              `json:"fee_paid"`       // Has teacher paid?
	CreatedAt     time.Time         `json:"created_at"`
	UpdatedAt     time.Time         `json:"updated_at"`
}

type SessionBrief struct {
	ID            uuid.UUID `json:"id"`
	SessionNumber int       `json:"session_number"`
	Title         string    `json:"title"`
	StartTime     time.Time `json:"start_time"`
	EndTime       time.Time `json:"end_time"`
	Status        string    `json:"status"`
}

type EnrollmentBrief struct {
	ID          uuid.UUID  `json:"id"`
	StudentID   uuid.UUID  `json:"student_id"`
	StudentName string     `json:"student_name"`
	InitiatedBy string     `json:"initiated_by"` // "teacher" or "student"
	Status      string     `json:"status"`
	CreatedAt   time.Time  `json:"created_at"`
	AcceptedAt  *time.Time `json:"accepted_at,omitempty"`
}

// ── Create Series ───────────────────────────────────────────────

type CreateSeriesRequest struct {
	OfferingID    *uuid.UUID `json:"offering_id"`
	Title         string     `json:"title" validate:"required,min=3,max=255"`
	Description   string     `json:"description" validate:"omitempty,max=5000"`
	SessionType   string     `json:"session_type" validate:"required,oneof=one_on_one group"`
	DurationHours float64    `json:"duration_hours" validate:"required,min=1,max=4"`
	MinStudents   int        `json:"min_students" validate:"omitempty,min=1,max=50"`
	MaxStudents   int        `json:"max_students" validate:"required,min=1,max=50"`
	PricePerHour  float64    `json:"price_per_hour" validate:"omitempty,min=0"`
}

// ── Add Sessions to Series ──────────────────────────────────────

type AddSessionsRequest struct {
	Sessions []SessionDateInput `json:"sessions" validate:"required,min=1,dive"`
}

type SessionDateInput struct {
	StartTime string `json:"start_time" validate:"required"` // RFC3339
}

// ═══════════════════════════════════════════════════════════════
// Enrollment DTOs
// ═══════════════════════════════════════════════════════════════

type InviteStudentsRequest struct {
	StudentIDs []string `json:"student_ids" validate:"required,min=1"`
}

type EnrollmentResponse struct {
	ID            uuid.UUID  `json:"id"`
	SeriesID      uuid.UUID  `json:"series_id"`
	SeriesTitle   string     `json:"series_title"`
	TeacherID     uuid.UUID  `json:"teacher_id"`
	TeacherName   string     `json:"teacher_name"`
	StudentID     uuid.UUID  `json:"student_id"`
	StudentName   string     `json:"student_name"`
	InitiatedBy   string     `json:"initiated_by"`
	Status        string     `json:"status"`
	SessionType   string     `json:"session_type"`
	TotalSessions int        `json:"total_sessions"`
	DurationHours float64    `json:"duration_hours"`
	InvitedAt     *time.Time `json:"invited_at,omitempty"`
	RequestedAt   *time.Time `json:"requested_at,omitempty"`
	AcceptedAt    *time.Time `json:"accepted_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
}

// ═══════════════════════════════════════════════════════════════
// Platform Fee DTOs
// ═══════════════════════════════════════════════════════════════

type PlatformFeeResponse struct {
	ID            uuid.UUID  `json:"id"`
	SeriesID      uuid.UUID  `json:"series_id"`
	SeriesTitle   string     `json:"series_title"`
	TeacherID     uuid.UUID  `json:"teacher_id"`
	EnrolledCount int        `json:"enrolled_count"`
	TotalSessions int        `json:"total_sessions"`
	DurationHours float64    `json:"duration_hours"`
	FeeRate       float64    `json:"fee_rate"`
	Amount        float64    `json:"amount"`
	Status        string     `json:"status"`
	ProviderRef   *string    `json:"provider_ref,omitempty"`
	Description   string     `json:"description,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	PaidAt        *time.Time `json:"paid_at,omitempty"`
}

type FinalizeSeriesRequest struct {
	// No body needed - fee is calculated from enrolled students
}

type ConfirmPaymentRequest struct {
	ProviderRef string `json:"provider_ref" validate:"required"` // BaridiMob transaction ref
}

// ═══════════════════════════════════════════════════════════════
// Join Session DTOs
// ═══════════════════════════════════════════════════════════════

type JoinResponse struct {
	RoomID    string `json:"room_id"`
	Token     string `json:"token"`
	IsTeacher bool   `json:"is_teacher"`
}

type AccessDeniedResponse struct {
	Allowed bool   `json:"allowed"`
	Reason  string `json:"reason,omitempty"` // "fee_not_paid", "not_enrolled", "session_not_started"
}

// ═══════════════════════════════════════════════════════════════
// List/Filter DTOs
// ═══════════════════════════════════════════════════════════════

type ListSeriesParams struct {
	Status string `form:"status"`
	Page   int    `form:"page"`
	Limit  int    `form:"limit"`
}

type ListEnrollmentsParams struct {
	Status string `form:"status"` // invited, requested, accepted
	Page   int    `form:"page"`
	Limit  int    `form:"limit"`
}

type PaginatedResponse struct {
	Data interface{}    `json:"data"`
	Meta PaginationMeta `json:"meta"`
}

type PaginationMeta struct {
	Page    int   `json:"page"`
	Limit   int   `json:"limit"`
	Total   int64 `json:"total"`
	HasMore bool  `json:"has_more"`
}
