package user

import (
	"time"

	"github.com/google/uuid"
)

// ─── Responses ──────────────────────────────────────────────────

// ProfileResponse is the full user profile.
type ProfileResponse struct {
	ID              uuid.UUID  `json:"id"`
	Email           string     `json:"email"`
	Phone           string     `json:"phone,omitempty"`
	Role            string     `json:"role"`
	FirstName       string     `json:"first_name"`
	LastName        string     `json:"last_name"`
	AvatarURL       string     `json:"avatar_url,omitempty"`
	Wilaya          string     `json:"wilaya,omitempty"`
	Language        string     `json:"language"`
	IsEmailVerified bool       `json:"is_email_verified"`
	IsPhoneVerified bool       `json:"is_phone_verified"`
	LastLoginAt     *time.Time `json:"last_login_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

// ─── Requests ───────────────────────────────────────────────────

// UpdateProfileRequest holds fields that can be updated.
type UpdateProfileRequest struct {
	FirstName *string `json:"first_name,omitempty" validate:"omitempty,min=2,max=50"`
	LastName  *string `json:"last_name,omitempty" validate:"omitempty,min=2,max=50"`
	Wilaya    *string `json:"wilaya,omitempty" validate:"omitempty,max=100"`
	Language  *string `json:"language,omitempty" validate:"omitempty,oneof=fr ar en"`
}

// ChangePasswordRequest requires old and new password.
type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=8"`
}
