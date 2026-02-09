package student

import (
	"errors"
	"net/http"
	"strconv"

	"educonnect/internal/middleware"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Dashboard GET /students/dashboard
func (h *Handler) Dashboard(c *gin.Context) {
	userID := middleware.GetUserID(c)
	dashboard, err := h.service.GetDashboard(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": dashboard})
}

// Progress GET /students/progress
func (h *Handler) Progress(c *gin.Context) {
	// For now, progress is part of the dashboard — returns enrollment stats.
	userID := middleware.GetUserID(c)
	dashboard, err := h.service.GetDashboard(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"total_sessions": dashboard.TotalSessions,
			"total_courses":  dashboard.TotalCourses,
			"profile":        dashboard.Profile,
		},
	})
}

// Enrollments GET /students/enrollments
func (h *Handler) Enrollments(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	userID := middleware.GetUserID(c)
	enrollments, total, err := h.service.GetEnrollments(c.Request.Context(), userID, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    enrollments,
		"meta": gin.H{
			"page":     page,
			"limit":    limit,
			"total":    total,
			"has_more": int64(page*limit) < total,
		},
	})
}

func handleError(c *gin.Context, err error) {
	if errors.Is(err, ErrProfileNotFound) {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "student profile not found"}})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
}
