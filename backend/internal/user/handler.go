package user

import (
	"errors"
	"io"
	"net/http"

	"educonnect/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type Handler struct {
	service  *Service
	validate *validator.Validate
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service, validate: validator.New()}
}

// GetProfile GET /users/me
func (h *Handler) GetProfile(c *gin.Context) {
	userID := middleware.GetUserID(c)

	profile, err := h.service.GetProfile(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": profile})
}

// UpdateProfile PUT /users/me
func (h *Handler) UpdateProfile(c *gin.Context) {
	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "invalid request body"}})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed", "details": formatValidation(err)}})
		return
	}

	userID := middleware.GetUserID(c)
	profile, err := h.service.UpdateProfile(c.Request.Context(), userID, req)
	if err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": profile})
}

// UploadAvatar PUT /users/me/avatar
func (h *Handler) UploadAvatar(c *gin.Context) {
	file, header, err := c.Request.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "avatar file required"}})
		return
	}
	defer file.Close()

	// Limit to 5MB
	if header.Size > 5*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "file size must be under 5MB"}})
		return
	}

	data, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "failed to read file"}})
		return
	}

	userID := middleware.GetUserID(c)
	profile, err := h.service.UploadAvatar(c.Request.Context(), userID, data, header.Header.Get("Content-Type"))
	if err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": profile})
}

// ChangePassword PUT /users/me/password
func (h *Handler) ChangePassword(c *gin.Context) {
	var req ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "invalid request body"}})
		return
	}

	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed", "details": formatValidation(err)}})
		return
	}

	userID := middleware.GetUserID(c)
	if err := h.service.ChangePassword(c.Request.Context(), userID, req); err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "password updated successfully"}})
}

// DeactivateAccount DELETE /users/me
func (h *Handler) DeactivateAccount(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if err := h.service.DeactivateAccount(c.Request.Context(), userID); err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "account deactivated"}})
}

// ─── Helpers ────────────────────────────────────────────────────

func handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "user not found"}})
	case errors.Is(err, ErrWrongPassword):
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": gin.H{"message": "current password is incorrect"}})
	case errors.Is(err, ErrUploadFailed):
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "avatar upload failed"}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}

func formatValidation(err error) map[string]string {
	fields := make(map[string]string)
	if ve, ok := err.(validator.ValidationErrors); ok {
		for _, e := range ve {
			fields[e.Field()] = e.Tag()
		}
	}
	return fields
}
