package teacher

import (
	"errors"
	"net/http"
	"strconv"

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

// GetTeacher GET /teachers/:id
func (h *Handler) GetTeacher(c *gin.Context) {
	teacherID := c.Param("id")
	profile, err := h.service.GetProfile(c.Request.Context(), teacherID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": profile})
}

// ListTeachers GET /teachers
func (h *Handler) ListTeachers(c *gin.Context) {
	wilaya := c.Query("wilaya")
	minRating, _ := strconv.ParseFloat(c.DefaultQuery("min_rating", "0"), 64)
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	teachers, total, err := h.service.ListTeachers(c.Request.Context(), wilaya, minRating, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    teachers,
		"meta": gin.H{
			"page":     page,
			"limit":    limit,
			"total":    total,
			"has_more": int64(page*limit) < total,
		},
	})
}

// UpdateProfile PUT /teachers/profile
func (h *Handler) UpdateProfile(c *gin.Context) {
	var req UpdateTeacherProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "invalid request body"}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
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

// Dashboard GET /teachers/dashboard
func (h *Handler) Dashboard(c *gin.Context) {
	userID := middleware.GetUserID(c)
	dashboard, err := h.service.GetDashboard(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": dashboard})
}

// CreateOffering POST /teachers/offerings
func (h *Handler) CreateOffering(c *gin.Context) {
	var req CreateOfferingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "invalid request body"}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	offering, err := h.service.CreateOffering(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "failed to create offering"}})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": offering})
}

// ListOfferings GET /teachers/offerings
func (h *Handler) ListOfferings(c *gin.Context) {
	userID := middleware.GetUserID(c)
	offerings, err := h.service.ListOfferings(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": offerings})
}

// UpdateOffering PUT /teachers/offerings/:id
func (h *Handler) UpdateOffering(c *gin.Context) {
	var req UpdateOfferingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "invalid request body"}})
		return
	}

	userID := middleware.GetUserID(c)
	offeringID := c.Param("id")
	offering, err := h.service.UpdateOffering(c.Request.Context(), userID, offeringID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": offering})
}

// DeleteOffering DELETE /teachers/offerings/:id
func (h *Handler) DeleteOffering(c *gin.Context) {
	userID := middleware.GetUserID(c)
	offeringID := c.Param("id")
	if err := h.service.DeleteOffering(c.Request.Context(), userID, offeringID); err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "offering deleted"}})
}

// SetAvailability PUT /teachers/availability
func (h *Handler) SetAvailability(c *gin.Context) {
	var req SetAvailabilityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "invalid request body"}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	slots, err := h.service.SetAvailability(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "failed to set availability"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": slots})
}

// GetAvailability GET /teachers/:id/availability
func (h *Handler) GetAvailability(c *gin.Context) {
	teacherID := c.Param("id")
	slots, err := h.service.GetAvailability(c.Request.Context(), teacherID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": slots})
}

// GetEarnings GET /teachers/earnings
func (h *Handler) GetEarnings(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	userID := middleware.GetUserID(c)
	earnings, err := h.service.GetEarnings(c.Request.Context(), userID, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": earnings})
}

// ─── Error Helper ───────────────────────────────────────────────

func handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrProfileNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "teacher profile not found"}})
	case errors.Is(err, ErrOfferingNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "offering not found"}})
	case errors.Is(err, ErrNotAuthorized):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{"message": "not authorized"}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
