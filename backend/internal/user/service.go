package user

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/cache"
	"educonnect/pkg/database"
	"educonnect/pkg/storage"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrNotFound      = errors.New("user not found")
	ErrWrongPassword = errors.New("current password is incorrect")
	ErrUploadFailed  = errors.New("avatar upload failed")
)

type Service struct {
	db      *database.Postgres
	cache   *cache.Redis
	storage *storage.MinIO
}

func NewService(db *database.Postgres, cache *cache.Redis, storage *storage.MinIO) *Service {
	return &Service{db: db, cache: cache, storage: storage}
}

// GetProfile returns the full profile for the authenticated user.
func (s *Service) GetProfile(ctx context.Context, userID string) (*ProfileResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrNotFound
	}

	var p ProfileResponse
	err = s.db.Pool.QueryRow(ctx,
		`SELECT id, COALESCE(email,''), COALESCE(phone,''), role, first_name, last_name,
		        COALESCE(avatar_url,''), COALESCE(wilaya,''), language,
		        is_email_verified, is_phone_verified, last_login_at, created_at
		 FROM users WHERE id = $1 AND is_active = true`, uid,
	).Scan(
		&p.ID, &p.Email, &p.Phone, &p.Role, &p.FirstName, &p.LastName,
		&p.AvatarURL, &p.Wilaya, &p.Language,
		&p.IsEmailVerified, &p.IsPhoneVerified, &p.LastLoginAt, &p.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("query user: %w", err)
	}

	return &p, nil
}

// UpdateProfile updates allowed profile fields.
func (s *Service) UpdateProfile(ctx context.Context, userID string, req UpdateProfileRequest) (*ProfileResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrNotFound
	}

	var p ProfileResponse
	err = s.db.Pool.QueryRow(ctx,
		`UPDATE users SET
			first_name = COALESCE($2, first_name),
			last_name  = COALESCE($3, last_name),
			wilaya     = COALESCE($4, wilaya),
			language   = COALESCE($5, language)
		 WHERE id = $1 AND is_active = true
		 RETURNING id, COALESCE(email,''), COALESCE(phone,''), role, first_name, last_name,
		           COALESCE(avatar_url,''), COALESCE(wilaya,''), language,
		           is_email_verified, is_phone_verified, last_login_at, created_at`,
		uid, req.FirstName, req.LastName, req.Wilaya, req.Language,
	).Scan(
		&p.ID, &p.Email, &p.Phone, &p.Role, &p.FirstName, &p.LastName,
		&p.AvatarURL, &p.Wilaya, &p.Language,
		&p.IsEmailVerified, &p.IsPhoneVerified, &p.LastLoginAt, &p.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("update user: %w", err)
	}

	return &p, nil
}

// ChangePassword verifies old password and sets the new one.
func (s *Service) ChangePassword(ctx context.Context, userID string, req ChangePasswordRequest) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return ErrNotFound
	}

	var currentHash string
	err = s.db.Pool.QueryRow(ctx,
		`SELECT password_hash FROM users WHERE id = $1 AND is_active = true`, uid,
	).Scan(&currentHash)
	if err != nil {
		return ErrNotFound
	}

	if err := bcrypt.CompareHashAndPassword([]byte(currentHash), []byte(req.OldPassword)); err != nil {
		return ErrWrongPassword
	}

	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	_, err = s.db.Pool.Exec(ctx, `UPDATE users SET password_hash = $2 WHERE id = $1`, uid, string(newHash))
	return err
}

// UploadAvatar uploads an avatar image and updates the user's avatar_url.
func (s *Service) UploadAvatar(ctx context.Context, userID string, fileData []byte, contentType string) (*ProfileResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrNotFound
	}

	objectKey := fmt.Sprintf("avatars/%s/%s", userID, uuid.New().String())

	err = s.storage.Upload(ctx, "avatars", objectKey, bytes.NewReader(fileData), int64(len(fileData)), contentType)
	if err != nil {
		return nil, ErrUploadFailed
	}

	presignedURL, err := s.storage.GetPresignedURL(ctx, "avatars", objectKey, 24*time.Hour)
	if err != nil {
		return nil, fmt.Errorf("generate URL: %w", err)
	}

	var p ProfileResponse
	err = s.db.Pool.QueryRow(ctx,
		`UPDATE users SET avatar_url = $2
		 WHERE id = $1 AND is_active = true
		 RETURNING id, COALESCE(email,''), COALESCE(phone,''), role, first_name, last_name,
		           avatar_url, COALESCE(wilaya,''), language,
		           is_email_verified, is_phone_verified, last_login_at, created_at`,
		uid, presignedURL,
	).Scan(
		&p.ID, &p.Email, &p.Phone, &p.Role, &p.FirstName, &p.LastName,
		&p.AvatarURL, &p.Wilaya, &p.Language,
		&p.IsEmailVerified, &p.IsPhoneVerified, &p.LastLoginAt, &p.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update avatar: %w", err)
	}

	return &p, nil
}

// DeactivateAccount soft-deletes the user.
func (s *Service) DeactivateAccount(ctx context.Context, userID string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return ErrNotFound
	}

	tag, err := s.db.Pool.Exec(ctx, `UPDATE users SET is_active = false WHERE id = $1`, uid)
	if err != nil {
		return fmt.Errorf("deactivate: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
