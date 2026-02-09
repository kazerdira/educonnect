package auth

import (
	"time"

	"github.com/google/uuid"
)

// ─── Request DTOs ───────────────────────────────────────────────

type RegisterTeacherRequest struct {
	Email           string   `json:"email" binding:"required,email"`
	Phone           string   `json:"phone" binding:"required,min=10,max=15"`
	Password        string   `json:"password" binding:"required,min=8"`
	FirstName       string   `json:"first_name" binding:"required,min=2,max=100"`
	LastName        string   `json:"last_name" binding:"required,min=2,max=100"`
	Wilaya          string   `json:"wilaya" binding:"required"`
	Bio             string   `json:"bio"`
	ExperienceYears int      `json:"experience_years"`
	Specializations []string `json:"specializations"`
}

type RegisterParentRequest struct {
	Email     string         `json:"email" binding:"required,email"`
	Phone     string         `json:"phone" binding:"required,min=10,max=15"`
	Password  string         `json:"password" binding:"required,min=8"`
	FirstName string         `json:"first_name" binding:"required,min=2,max=100"`
	LastName  string         `json:"last_name" binding:"required,min=2,max=100"`
	Wilaya    string         `json:"wilaya" binding:"required"`
	Children  []ChildRequest `json:"children"`
}

type ChildRequest struct {
	FirstName   string `json:"first_name" binding:"required"`
	LastName    string `json:"last_name" binding:"required"`
	DateOfBirth string `json:"date_of_birth"` // YYYY-MM-DD
	LevelCode   string `json:"level_code"`    // e.g. "3AM", "2AS-SE"
	School      string `json:"school"`
}

type RegisterStudentRequest struct {
	Email       string `json:"email" binding:"required,email"`
	Phone       string `json:"phone" binding:"required,min=10,max=15"`
	Password    string `json:"password" binding:"required,min=8"`
	FirstName   string `json:"first_name" binding:"required,min=2,max=100"`
	LastName    string `json:"last_name" binding:"required,min=2,max=100"`
	Wilaya      string `json:"wilaya"`
	DateOfBirth string `json:"date_of_birth"`
	LevelCode   string `json:"level_code"`
	Filiere     string `json:"filiere"`
	School      string `json:"school"`
	ParentPhone string `json:"parent_phone"` // optional: link to parent
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type PhoneLoginRequest struct {
	Phone string `json:"phone" binding:"required,min=10,max=15"`
}

type VerifyOTPRequest struct {
	Phone string `json:"phone" binding:"required"`
	Code  string `json:"code" binding:"required,len=6"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type ResetPasswordRequest struct {
	Token       string `json:"token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

// ─── Response DTOs ──────────────────────────────────────────────

type AuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	ExpiresIn    int64        `json:"expires_in"` // seconds
	User         UserResponse `json:"user"`
}

type UserResponse struct {
	ID              uuid.UUID `json:"id"`
	Email           string    `json:"email"`
	Phone           string    `json:"phone"`
	Role            string    `json:"role"`
	FirstName       string    `json:"first_name"`
	LastName        string    `json:"last_name"`
	AvatarURL       *string   `json:"avatar_url"`
	Wilaya          string    `json:"wilaya"`
	Language        string    `json:"language"`
	IsEmailVerified bool      `json:"is_email_verified"`
	IsPhoneVerified bool      `json:"is_phone_verified"`
	CreatedAt       time.Time `json:"created_at"`
}

type OTPResponse struct {
	Message   string `json:"message"`
	ExpiresIn int    `json:"expires_in"` // seconds
}
