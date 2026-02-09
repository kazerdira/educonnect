package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"time"

	"educonnect/internal/config"
	"educonnect/internal/middleware"
	"educonnect/pkg/cache"
	"educonnect/pkg/database"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrUserExists         = errors.New("user with this email or phone already exists")
	ErrInvalidOTP         = errors.New("invalid or expired OTP code")
	ErrTooManyOTPAttempts = errors.New("too many OTP attempts, please try again later")
	ErrInvalidToken       = errors.New("invalid or expired token")
	ErrUserNotFound       = errors.New("user not found")
)

// Service handles authentication business logic.
type Service struct {
	db    *database.Postgres
	cache *cache.Redis
	cfg   *config.Config
}

// NewService creates a new auth service.
func NewService(db *database.Postgres, cache *cache.Redis, cfg *config.Config) *Service {
	return &Service{db: db, cache: cache, cfg: cfg}
}

// ─── Registration ───────────────────────────────────────────────

// RegisterTeacher creates a new teacher account with pending verification.
func (s *Service) RegisterTeacher(ctx context.Context, req RegisterTeacherRequest) (*AuthResponse, error) {
	// Check if user exists
	if exists, _ := s.userExistsByEmailOrPhone(ctx, req.Email, req.Phone); exists {
		return nil, ErrUserExists
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Create user
	var userID uuid.UUID
	var createdAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, phone, password_hash, role, first_name, last_name, wilaya, language)
		 VALUES ($1, $2, $3, 'teacher', $4, $5, $6, 'fr')
		 RETURNING id, created_at`,
		req.Email, req.Phone, string(hash), req.FirstName, req.LastName, req.Wilaya,
	).Scan(&userID, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	// Create teacher profile
	_, err = tx.Exec(ctx,
		`INSERT INTO teacher_profiles (user_id, bio, experience_years, specializations)
		 VALUES ($1, $2, $3, $4)`,
		userID, req.Bio, req.ExperienceYears, req.Specializations,
	)
	if err != nil {
		return nil, fmt.Errorf("create teacher profile: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	// Generate tokens
	return s.generateAuthResponse(ctx, userID, req.Email, "teacher", req.FirstName, req.LastName, &req.Wilaya, createdAt)
}

// RegisterParent creates a new parent account.
func (s *Service) RegisterParent(ctx context.Context, req RegisterParentRequest) (*AuthResponse, error) {
	if exists, _ := s.userExistsByEmailOrPhone(ctx, req.Email, req.Phone); exists {
		return nil, ErrUserExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Create parent user
	var userID uuid.UUID
	var createdAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, phone, password_hash, role, first_name, last_name, wilaya, language)
		 VALUES ($1, $2, $3, 'parent', $4, $5, $6, 'fr')
		 RETURNING id, created_at`,
		req.Email, req.Phone, string(hash), req.FirstName, req.LastName, req.Wilaya,
	).Scan(&userID, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	// Create parent profile
	_, err = tx.Exec(ctx, `INSERT INTO parent_profiles (user_id) VALUES ($1)`, userID)
	if err != nil {
		return nil, fmt.Errorf("create parent profile: %w", err)
	}

	// Create child accounts if provided
	for _, child := range req.Children {
		childHash, _ := bcrypt.GenerateFromPassword([]byte(generateTempPassword()), 12)

		var childID uuid.UUID
		err = tx.QueryRow(ctx,
			`INSERT INTO users (password_hash, role, first_name, last_name, wilaya, language)
			 VALUES ($1, 'student', $2, $3, $4, 'fr')
			 RETURNING id`,
			string(childHash), child.FirstName, child.LastName, req.Wilaya,
		).Scan(&childID)
		if err != nil {
			return nil, fmt.Errorf("create child user: %w", err)
		}

		// Look up level by code
		var levelID *uuid.UUID
		if child.LevelCode != "" {
			var lid uuid.UUID
			err = tx.QueryRow(ctx, `SELECT id FROM levels WHERE code = $1`, child.LevelCode).Scan(&lid)
			if err == nil {
				levelID = &lid
			}
		}

		_, err = tx.Exec(ctx,
			`INSERT INTO student_profiles (user_id, level_id, parent_id, school, date_of_birth, is_independent)
			 VALUES ($1, $2, $3, $4, $5, false)`,
			childID, levelID, userID, child.School, parseDate(child.DateOfBirth),
		)
		if err != nil {
			return nil, fmt.Errorf("create child profile: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return s.generateAuthResponse(ctx, userID, req.Email, "parent", req.FirstName, req.LastName, &req.Wilaya, createdAt)
}

// RegisterStudent creates a new independent student account.
func (s *Service) RegisterStudent(ctx context.Context, req RegisterStudentRequest) (*AuthResponse, error) {
	if exists, _ := s.userExistsByEmailOrPhone(ctx, req.Email, req.Phone); exists {
		return nil, ErrUserExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var userID uuid.UUID
	var createdAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, phone, password_hash, role, first_name, last_name, wilaya, language)
		 VALUES ($1, $2, $3, 'student', $4, $5, $6, 'fr')
		 RETURNING id, created_at`,
		req.Email, req.Phone, string(hash), req.FirstName, req.LastName, req.Wilaya,
	).Scan(&userID, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	// Look up level
	var levelID *uuid.UUID
	if req.LevelCode != "" {
		var lid uuid.UUID
		err = tx.QueryRow(ctx, `SELECT id FROM levels WHERE code = $1`, req.LevelCode).Scan(&lid)
		if err == nil {
			levelID = &lid
		}
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO student_profiles (user_id, level_id, filiere, school, date_of_birth, is_independent)
		 VALUES ($1, $2, $3, $4, $5, true)`,
		userID, levelID, nilIfEmpty(req.Filiere), nilIfEmpty(req.School), parseDate(req.DateOfBirth),
	)
	if err != nil {
		return nil, fmt.Errorf("create student profile: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return s.generateAuthResponse(ctx, userID, req.Email, "student", req.FirstName, req.LastName, &req.Wilaya, createdAt)
}

// ─── Login ──────────────────────────────────────────────────────

// Login authenticates a user with email and password.
func (s *Service) Login(ctx context.Context, req LoginRequest) (*AuthResponse, error) {
	var (
		userID       uuid.UUID
		passwordHash string
		role         string
		firstName    string
		lastName     string
		wilaya       *string
		createdAt    time.Time
	)

	err := s.db.Pool.QueryRow(ctx,
		`SELECT id, password_hash, role, first_name, last_name, wilaya, created_at
		 FROM users WHERE email = $1 AND is_active = true`,
		req.Email,
	).Scan(&userID, &passwordHash, &role, &firstName, &lastName, &wilaya, &createdAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrInvalidCredentials
		}
		return nil, fmt.Errorf("query user: %w", err)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	// Update last login
	_, _ = s.db.Pool.Exec(ctx, `UPDATE users SET last_login_at = NOW() WHERE id = $1`, userID)

	return s.generateAuthResponse(ctx, userID, req.Email, role, firstName, lastName, wilaya, createdAt)
}

// ─── OTP ────────────────────────────────────────────────────────

// SendOTP generates and stores an OTP for phone-based login.
func (s *Service) SendOTP(ctx context.Context, phone string) (*OTPResponse, error) {
	// Check rate limit
	attempts, err := s.cache.IncrOTPAttempts(ctx, phone)
	if err != nil {
		slog.Error("otp rate check failed", "error", err)
	}
	if attempts > 5 {
		return nil, ErrTooManyOTPAttempts
	}

	// Generate 6-digit OTP
	code := generateOTP()

	// Store in Redis with 5-minute expiry
	if err := s.cache.SetOTP(ctx, phone, code, 5*time.Minute); err != nil {
		return nil, fmt.Errorf("store OTP: %w", err)
	}

	// TODO: Send OTP via SMS (ICOSNET/Twilio)
	slog.Info("OTP generated", "phone", phone, "code", code) // Remove in production!

	return &OTPResponse{
		Message:   "OTP sent successfully",
		ExpiresIn: 300,
	}, nil
}

// VerifyOTP verifies the OTP and returns auth tokens.
func (s *Service) VerifyOTP(ctx context.Context, req VerifyOTPRequest) (*AuthResponse, error) {
	stored, err := s.cache.GetOTP(ctx, req.Phone)
	if err != nil {
		return nil, ErrInvalidOTP
	}

	if stored != req.Code {
		return nil, ErrInvalidOTP
	}

	// Delete used OTP
	_ = s.cache.DeleteOTP(ctx, req.Phone)

	// Find user by phone
	var (
		userID    uuid.UUID
		email     string
		role      string
		firstName string
		lastName  string
		wilaya    *string
		createdAt time.Time
	)

	err = s.db.Pool.QueryRow(ctx,
		`SELECT id, COALESCE(email, ''), role, first_name, last_name, wilaya, created_at
		 FROM users WHERE phone = $1 AND is_active = true`,
		req.Phone,
	).Scan(&userID, &email, &role, &firstName, &lastName, &wilaya, &createdAt)

	if err != nil {
		return nil, ErrUserNotFound
	}

	// Mark phone as verified
	_, _ = s.db.Pool.Exec(ctx, `UPDATE users SET is_phone_verified = true, last_login_at = NOW() WHERE id = $1`, userID)

	return s.generateAuthResponse(ctx, userID, email, role, firstName, lastName, wilaya, createdAt)
}

// ─── Token Refresh ──────────────────────────────────────────────

// RefreshToken generates new access/refresh tokens from a valid refresh token.
func (s *Service) RefreshToken(ctx context.Context, refreshToken string) (*AuthResponse, error) {
	tokenHash := hashToken(refreshToken)

	var (
		userID    uuid.UUID
		expiresAt time.Time
	)

	err := s.db.Pool.QueryRow(ctx,
		`SELECT user_id, expires_at FROM refresh_tokens WHERE token_hash = $1`,
		tokenHash,
	).Scan(&userID, &expiresAt)

	if err != nil || time.Now().After(expiresAt) {
		return nil, ErrInvalidToken
	}

	// Delete old refresh token (rotation)
	_, _ = s.db.Pool.Exec(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, tokenHash)

	// Get user info
	var (
		email     string
		role      string
		firstName string
		lastName  string
		wilaya    *string
		createdAt time.Time
	)

	err = s.db.Pool.QueryRow(ctx,
		`SELECT COALESCE(email, ''), role, first_name, last_name, wilaya, created_at
		 FROM users WHERE id = $1 AND is_active = true`,
		userID,
	).Scan(&email, &role, &firstName, &lastName, &wilaya, &createdAt)

	if err != nil {
		return nil, ErrUserNotFound
	}

	return s.generateAuthResponse(ctx, userID, email, role, firstName, lastName, wilaya, createdAt)
}

// ─── Helpers ────────────────────────────────────────────────────

func (s *Service) generateAuthResponse(ctx context.Context, userID uuid.UUID, email, role, firstName, lastName string, wilaya *string, createdAt time.Time) (*AuthResponse, error) {
	// Generate access token
	now := time.Now()
	accessClaims := &middleware.Claims{
		UserID: userID.String(),
		Role:   role,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(s.cfg.JWT.AccessExpiry)),
			IssuedAt:  jwt.NewNumericDate(now),
			Issuer:    "educonnect",
		},
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString([]byte(s.cfg.JWT.Secret))
	if err != nil {
		return nil, fmt.Errorf("sign access token: %w", err)
	}

	// Generate refresh token (opaque)
	refreshTokenString := generateRefreshToken()
	refreshHash := hashToken(refreshTokenString)

	// Store refresh token in DB
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, refreshHash, now.Add(s.cfg.JWT.RefreshExpiry),
	)
	if err != nil {
		return nil, fmt.Errorf("store refresh token: %w", err)
	}

	w := ""
	if wilaya != nil {
		w = *wilaya
	}

	return &AuthResponse{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresIn:    int64(s.cfg.JWT.AccessExpiry.Seconds()),
		User: UserResponse{
			ID:        userID,
			Email:     email,
			Role:      role,
			FirstName: firstName,
			LastName:  lastName,
			Wilaya:    w,
			Language:  "fr",
			CreatedAt: createdAt,
		},
	}, nil
}

func (s *Service) userExistsByEmailOrPhone(ctx context.Context, email, phone string) (bool, error) {
	var count int
	err := s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM users WHERE (email = $1 OR phone = $2) AND is_active = true`,
		email, phone,
	).Scan(&count)
	return count > 0, err
}

func generateOTP() string {
	n, _ := rand.Int(rand.Reader, big.NewInt(999999))
	return fmt.Sprintf("%06d", n.Int64())
}

func generateRefreshToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func generateTempPassword() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func parseDate(s string) *time.Time {
	if s == "" {
		return nil
	}
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return nil
	}
	return &t
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
