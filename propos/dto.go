package sessionseries

import (
	"time"

	"github.com/google/uuid"
)

// ═══════════════════════════════════════════════════════════════
// Platform Fee Constants
// ═══════════════════════════════════════════════════════════════

const (
	GroupFeePerHour      = 50.0  // DA per student per hour
	IndividualFeePerHour = 120.0 // DA per hour (paid by teacher)
)

// ═══════════════════════════════════════════════════════════════
// Session Series
// ═══════════════════════════════════════════════════════════════

type SeriesResponse struct {
	ID              uuid.UUID          `json:"id"`
	TeacherID       uuid.UUID          `json:"teacher_id"`
	TeacherName     string             `json:"teacher_name"`
	OfferingID      *uuid.UUID         `json:"offering_id,omitempty"`
	Title           string             `json:"title"`
	Description     string             `json:"description,omitempty"`
	SessionType     string             `json:"session_type"` // "individual" or "group"
	DurationHours   float64            `json:"duration_hours"`
	MinStudents     int                `json:"min_students"`
	MaxStudents     int                `json:"max_students"`
	TotalSessions   int                `json:"total_sessions"`
	PlatformFeeRate float64            `json:"platform_fee_rate"`
	Status          string             `json:"status"`
	Sessions        []SessionBrief     `json:"sessions,omitempty"`
	Enrollments     []EnrollmentBrief  `json:"enrollments,omitempty"`
	EnrolledCount   int                `json:"enrolled_count"`
	CreatedAt       time.Time          `json:"created_at"`
	UpdatedAt       time.Time          `json:"updated_at"`
}

type SessionBrief struct {
	ID            uuid.UUID `json:"id"`
	SessionNumber int       `json:"session_number"`
	StartTime     time.Time `json:"start_time"`
	EndTime       time.Time `json:"end_time"`
	Status        string    `json:"status"`
}

type EnrollmentBrief struct {
	ID          uuid.UUID `json:"id"`
	StudentID   uuid.UUID `json:"student_id"`
	StudentName string    `json:"student_name"`
	Status      string    `json:"status"`
	PlatformFee float64   `json:"platform_fee"`
	FeePaid     bool      `json:"fee_paid"`
}

// ── Create Series ───────────────────────────────────────────────

type CreateSeriesRequest struct {
	OfferingID    *uuid.UUID `json:"offering_id"`
	Title         string     `json:"title" validate:"required,min=3,max=255"`
	Description   string     `json:"description" validate:"omitempty,max=5000"`
	SessionType   string     `json:"session_type" validate:"required,oneof=individual group"`
	DurationHours float64    `json:"duration_hours" validate:"required,min=1,max=4"`
	MinStudents   int        `json:"min_students" validate:"omitempty,min=1,max=50"`
	MaxStudents   int        `json:"max_students" validate:"required,min=1,max=50"`
	// Sessions are added separately via AddSessions
}

// ── Add Sessions to Series ──────────────────────────────────────

type AddSessionsRequest struct {
	Sessions []SessionDateInput `json:"sessions" validate:"required,min=1,dive"`
}

type SessionDateInput struct {
	StartTime string `json:"start_time" validate:"required"` // RFC3339
	EndTime   string `json:"end_time" validate:"required"`   // RFC3339
}

// ═══════════════════════════════════════════════════════════════
// Invitations
// ═══════════════════════════════════════════════════════════════

type InviteStudentsRequest struct {
	StudentIDs []string `json:"student_ids" validate:"required,min=1"`
}

type InvitationResponse struct {
	ID          uuid.UUID  `json:"id"`
	SeriesID    *uuid.UUID `json:"series_id,omitempty"`
	SessionID   *uuid.UUID `json:"session_id,omitempty"`
	SeriesTitle string     `json:"series_title,omitempty"`
	TeacherName string     `json:"teacher_name"`
	StudentID   uuid.UUID  `json:"student_id"`
	StudentName string     `json:"student_name"`
	Status      string     `json:"status"`
	SessionType string     `json:"session_type"`
	PlatformFee float64    `json:"platform_fee"`
	FeePaid     bool       `json:"fee_paid"`
	FeePayer    string     `json:"fee_payer"` // "student" or "teacher"
	InvitedAt   time.Time  `json:"invited_at"`
	AcceptedAt  *time.Time `json:"accepted_at,omitempty"`
}

// ═══════════════════════════════════════════════════════════════
// Platform Fees
// ═══════════════════════════════════════════════════════════════

type PlatformFeeResponse struct {
	ID           uuid.UUID  `json:"id"`
	EnrollmentID uuid.UUID  `json:"enrollment_id"`
	PayerID      uuid.UUID  `json:"payer_id"`
	PayerName    string     `json:"payer_name"`
	Amount       float64    `json:"amount"`
	Description  string     `json:"description,omitempty"`
	Status       string     `json:"status"`
	ProviderRef  *string    `json:"provider_ref,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	PaidAt       *time.Time `json:"paid_at,omitempty"`
}

type ConfirmFeePaymentRequest struct {
	ProviderRef string `json:"provider_ref" validate:"required"`
}

// ═══════════════════════════════════════════════════════════════
// Join Session
// ═══════════════════════════════════════════════════════════════

type JoinResponse struct {
	RoomID    string `json:"room_id"`
	Token     string `json:"token"`
	IsTeacher bool   `json:"is_teacher"`
}

type AccessDeniedReason struct {
	Allowed bool   `json:"allowed"`
	Reason  string `json:"reason,omitempty"` // "fee_not_paid", "not_enrolled", etc.
}
