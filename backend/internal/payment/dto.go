package payment

import (
	"time"

	"github.com/google/uuid"
)

// ─── Transaction ────────────────────────────────────────────────

type TransactionResponse struct {
	ID                uuid.UUID  `json:"id"`
	PayerID           uuid.UUID  `json:"payer_id"`
	PayerName         string     `json:"payer_name,omitempty"`
	PayeeID           uuid.UUID  `json:"payee_id"`
	PayeeName         string     `json:"payee_name,omitempty"`
	SessionID         *uuid.UUID `json:"session_id,omitempty"`
	CourseID          *uuid.UUID `json:"course_id,omitempty"`
	SubscriptionID    *uuid.UUID `json:"subscription_id,omitempty"`
	Amount            float64    `json:"amount"`
	Commission        float64    `json:"commission"`
	NetAmount         float64    `json:"net_amount"`
	PaymentMethod     string     `json:"payment_method"`
	Status            string     `json:"status"`
	ProviderReference *string    `json:"provider_reference,omitempty"`
	Description       *string    `json:"description,omitempty"`
	RefundAmount      float64    `json:"refund_amount"`
	RefundReason      *string    `json:"refund_reason,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type InitiatePaymentRequest struct {
	PayeeID       uuid.UUID  `json:"payee_id" validate:"required"`
	SessionID     *uuid.UUID `json:"session_id,omitempty"`
	CourseID      *uuid.UUID `json:"course_id,omitempty"`
	Amount        float64    `json:"amount" validate:"required,gt=0"`
	PaymentMethod string     `json:"payment_method" validate:"required,oneof=ccp_baridimob edahabia"`
	Description   *string    `json:"description,omitempty"`
}

type ConfirmPaymentRequest struct {
	TransactionID     uuid.UUID `json:"transaction_id" validate:"required"`
	ProviderReference string    `json:"provider_reference" validate:"required"`
}

type RefundPaymentRequest struct {
	TransactionID uuid.UUID `json:"transaction_id" validate:"required"`
	Amount        float64   `json:"amount" validate:"required,gt=0"`
	Reason        string    `json:"reason" validate:"required"`
}

// ─── Subscription ───────────────────────────────────────────────

type SubscriptionResponse struct {
	ID               uuid.UUID `json:"id"`
	StudentID        uuid.UUID `json:"student_id"`
	TeacherID        uuid.UUID `json:"teacher_id"`
	TeacherName      string    `json:"teacher_name,omitempty"`
	PlanType         string    `json:"plan_type"`
	SessionsPerMonth int       `json:"sessions_per_month"`
	SessionsUsed     int       `json:"sessions_used"`
	Price            float64   `json:"price"`
	Status           string    `json:"status"`
	StartDate        string    `json:"start_date"`
	EndDate          string    `json:"end_date"`
	AutoRenew        bool      `json:"auto_renew"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type CreateSubscriptionRequest struct {
	TeacherID        uuid.UUID `json:"teacher_id" validate:"required"`
	PlanType         string    `json:"plan_type" validate:"required"`
	SessionsPerMonth int       `json:"sessions_per_month" validate:"required,min=1"`
	Price            float64   `json:"price" validate:"required,gt=0"`
	StartDate        string    `json:"start_date" validate:"required"`
	EndDate          string    `json:"end_date" validate:"required"`
	AutoRenew        *bool     `json:"auto_renew,omitempty"`
}
