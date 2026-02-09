package auth

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

// Handler handles auth-related HTTP requests.
type Handler struct {
	service  *Service
	validate *validator.Validate
}

// NewHandler creates a new auth handler.
func NewHandler(service *Service) *Handler {
	return &Handler{
		service:  service,
		validate: validator.New(),
	}
}

// RegisterTeacher godoc
// @Summary Register a new teacher
// @Tags auth
// @Accept json
// @Produce json
// @Param body body RegisterTeacherRequest true "Teacher registration"
// @Success 201 {object} AuthResponse
// @Router /auth/register/teacher [post]
func (h *Handler) RegisterTeacher(c *gin.Context) {
	var req RegisterTeacherRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		validationErrors := err.(validator.ValidationErrors)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "validation failed",
			"fields": formatValidationErrors(validationErrors),
		})
		return
	}

	resp, err := h.service.RegisterTeacher(c.Request.Context(), req)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": resp})
}

// RegisterParent godoc
// @Summary Register a new parent
// @Tags auth
// @Accept json
// @Produce json
// @Param body body RegisterParentRequest true "Parent registration"
// @Success 201 {object} AuthResponse
// @Router /auth/register/parent [post]
func (h *Handler) RegisterParent(c *gin.Context) {
	var req RegisterParentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		validationErrors := err.(validator.ValidationErrors)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "validation failed",
			"fields": formatValidationErrors(validationErrors),
		})
		return
	}

	resp, err := h.service.RegisterParent(c.Request.Context(), req)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": resp})
}

// RegisterStudent godoc
// @Summary Register a new independent student
// @Tags auth
// @Accept json
// @Produce json
// @Param body body RegisterStudentRequest true "Student registration"
// @Success 201 {object} AuthResponse
// @Router /auth/register/student [post]
func (h *Handler) RegisterStudent(c *gin.Context) {
	var req RegisterStudentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		validationErrors := err.(validator.ValidationErrors)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "validation failed",
			"fields": formatValidationErrors(validationErrors),
		})
		return
	}

	resp, err := h.service.RegisterStudent(c.Request.Context(), req)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": resp})
}

// Login godoc
// @Summary Login with email and password
// @Tags auth
// @Accept json
// @Produce json
// @Param body body LoginRequest true "Login credentials"
// @Success 200 {object} AuthResponse
// @Router /auth/login [post]
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		validationErrors := err.(validator.ValidationErrors)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "validation failed",
			"fields": formatValidationErrors(validationErrors),
		})
		return
	}

	resp, err := h.service.Login(c.Request.Context(), req)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": resp})
}

// PhoneLogin godoc
// @Summary Request OTP for phone login
// @Tags auth
// @Accept json
// @Produce json
// @Param body body PhoneLoginRequest true "Phone number"
// @Success 200 {object} OTPResponse
// @Router /auth/phone/login [post]
func (h *Handler) PhoneLogin(c *gin.Context) {
	var req PhoneLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		validationErrors := err.(validator.ValidationErrors)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "validation failed",
			"fields": formatValidationErrors(validationErrors),
		})
		return
	}

	resp, err := h.service.SendOTP(c.Request.Context(), req.Phone)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": resp})
}

// VerifyOTP godoc
// @Summary Verify OTP code
// @Tags auth
// @Accept json
// @Produce json
// @Param body body VerifyOTPRequest true "OTP verification"
// @Success 200 {object} AuthResponse
// @Router /auth/phone/verify [post]
func (h *Handler) VerifyOTP(c *gin.Context) {
	var req VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		validationErrors := err.(validator.ValidationErrors)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "validation failed",
			"fields": formatValidationErrors(validationErrors),
		})
		return
	}

	resp, err := h.service.VerifyOTP(c.Request.Context(), req)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": resp})
}

// RefreshToken godoc
// @Summary Refresh access token
// @Tags auth
// @Accept json
// @Produce json
// @Param body body RefreshTokenRequest true "Refresh token"
// @Success 200 {object} AuthResponse
// @Router /auth/refresh [post]
func (h *Handler) RefreshToken(c *gin.Context) {
	var req RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	resp, err := h.service.RefreshToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": resp})
}

// ─── Helpers ────────────────────────────────────────────────────

func handleServiceError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrInvalidCredentials):
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
	case errors.Is(err, ErrUserExists):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, ErrInvalidOTP):
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
	case errors.Is(err, ErrTooManyOTPAttempts):
		c.JSON(http.StatusTooManyRequests, gin.H{"error": err.Error()})
	case errors.Is(err, ErrInvalidToken):
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
	case errors.Is(err, ErrUserNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
	}
}

func formatValidationErrors(errs validator.ValidationErrors) map[string]string {
	fields := make(map[string]string, len(errs))
	for _, e := range errs {
		switch e.Tag() {
		case "required":
			fields[e.Field()] = "this field is required"
		case "email":
			fields[e.Field()] = "invalid email address"
		case "min":
			fields[e.Field()] = "must be at least " + e.Param() + " characters"
		case "max":
			fields[e.Field()] = "must be at most " + e.Param() + " characters"
		case "oneof":
			fields[e.Field()] = "must be one of: " + e.Param()
		default:
			fields[e.Field()] = "invalid value"
		}
	}
	return fields
}
