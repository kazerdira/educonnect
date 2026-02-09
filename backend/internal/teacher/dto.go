package teacher

import (
	"time"

	"github.com/google/uuid"
)

// ─── Teacher Profile ────────────────────────────────────────────

type TeacherProfileResponse struct {
	UserID             uuid.UUID `json:"user_id"`
	FirstName          string    `json:"first_name"`
	LastName           string    `json:"last_name"`
	AvatarURL          string    `json:"avatar_url,omitempty"`
	Email              string    `json:"email"`
	Phone              string    `json:"phone,omitempty"`
	Wilaya             string    `json:"wilaya,omitempty"`
	Bio                string    `json:"bio,omitempty"`
	ExperienceYears    int       `json:"experience_years"`
	Specializations    []string  `json:"specializations,omitempty"`
	VerificationStatus string    `json:"verification_status"`
	RatingAvg          float64   `json:"rating_avg"`
	RatingCount        int       `json:"rating_count"`
	TotalSessions      int       `json:"total_sessions"`
	TotalStudents      int       `json:"total_students"`
	CompletionRate     float64   `json:"completion_rate"`
}

type UpdateTeacherProfileRequest struct {
	Bio             *string  `json:"bio,omitempty" validate:"omitempty,max=2000"`
	ExperienceYears *int     `json:"experience_years,omitempty" validate:"omitempty,min=0,max=50"`
	Specializations []string `json:"specializations,omitempty"`
}

// ─── Offerings ──────────────────────────────────────────────────

type OfferingResponse struct {
	ID                uuid.UUID `json:"id"`
	TeacherID         uuid.UUID `json:"teacher_id"`
	SubjectID         uuid.UUID `json:"subject_id"`
	SubjectName       string    `json:"subject_name"`
	LevelID           uuid.UUID `json:"level_id"`
	LevelName         string    `json:"level_name"`
	LevelCode         string    `json:"level_code"`
	SessionType       string    `json:"session_type"`
	PricePerHour      float64   `json:"price_per_hour"`
	MaxStudents       int       `json:"max_students"`
	FreeTrialEnabled  bool      `json:"free_trial_enabled"`
	FreeTrialDuration int       `json:"free_trial_duration"`
	IsActive          bool      `json:"is_active"`
}

type CreateOfferingRequest struct {
	SubjectID         uuid.UUID `json:"subject_id" validate:"required"`
	LevelID           uuid.UUID `json:"level_id" validate:"required"`
	SessionType       string    `json:"session_type" validate:"required,oneof=one_on_one group"`
	PricePerHour      float64   `json:"price_per_hour" validate:"required,gt=0"`
	MaxStudents       int       `json:"max_students" validate:"omitempty,min=1,max=50"`
	FreeTrialEnabled  bool      `json:"free_trial_enabled"`
	FreeTrialDuration int       `json:"free_trial_duration" validate:"omitempty,min=0,max=60"`
}

type UpdateOfferingRequest struct {
	PricePerHour     *float64 `json:"price_per_hour,omitempty" validate:"omitempty,gt=0"`
	MaxStudents      *int     `json:"max_students,omitempty" validate:"omitempty,min=1,max=50"`
	FreeTrialEnabled *bool    `json:"free_trial_enabled,omitempty"`
	IsActive         *bool    `json:"is_active,omitempty"`
}

// ─── Availability ───────────────────────────────────────────────

type AvailabilitySlotResponse struct {
	ID        uuid.UUID `json:"id"`
	DayOfWeek int       `json:"day_of_week"`
	StartTime string    `json:"start_time"`
	EndTime   string    `json:"end_time"`
}

type SetAvailabilityRequest struct {
	Slots []AvailabilitySlotInput `json:"slots" validate:"required,dive"`
}

type AvailabilitySlotInput struct {
	DayOfWeek int    `json:"day_of_week" validate:"required,min=0,max=6"`
	StartTime string `json:"start_time" validate:"required"`
	EndTime   string `json:"end_time" validate:"required"`
}

// ─── Earnings ───────────────────────────────────────────────────

type EarningsResponse struct {
	TotalEarnings    float64              `json:"total_earnings"`
	MonthEarnings    float64              `json:"month_earnings"`
	AvailableBalance float64              `json:"available_balance"`
	Transactions     []TransactionSummary `json:"transactions,omitempty"`
}

type TransactionSummary struct {
	ID            uuid.UUID `json:"id"`
	PayerName     string    `json:"payer_name"`
	Amount        float64   `json:"amount"`
	Commission    float64   `json:"commission"`
	NetAmount     float64   `json:"net_amount"`
	PaymentMethod string    `json:"payment_method"`
	Status        string    `json:"status"`
	CreatedAt     time.Time `json:"created_at"`
}

// ─── Dashboard ──────────────────────────────────────────────────

type TeacherDashboardResponse struct {
	Profile          TeacherProfileResponse `json:"profile"`
	UpcomingSessions []SessionBrief         `json:"upcoming_sessions"`
	Earnings         EarningsResponse       `json:"earnings"`
	RecentReviews    []ReviewBrief          `json:"recent_reviews"`
}

type SessionBrief struct {
	ID               uuid.UUID `json:"id"`
	Title            string    `json:"title"`
	StartTime        time.Time `json:"start_time"`
	EndTime          time.Time `json:"end_time"`
	Status           string    `json:"status"`
	ParticipantCount int       `json:"participant_count"`
}

type ReviewBrief struct {
	ID           uuid.UUID `json:"id"`
	ReviewerName string    `json:"reviewer_name"`
	Rating       int       `json:"rating"`
	ReviewText   string    `json:"review_text,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}
