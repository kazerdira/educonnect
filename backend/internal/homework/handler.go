package homework

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

// CreateHomework POST /homework
func (h *Handler) CreateHomework(c *gin.Context) {
	var req CreateHomeworkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	hw, err := h.service.CreateHomework(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "failed to create homework"}})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": hw})
}

// ListHomework GET /homework
func (h *Handler) ListHomework(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	userID := middleware.GetUserID(c)
	role := middleware.GetUserRole(c)

	list, total, err := h.service.ListHomework(c.Request.Context(), userID, role, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    list,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// GetHomework GET /homework/:id
func (h *Handler) GetHomework(c *gin.Context) {
	id := c.Param("id")
	hw, err := h.service.GetHomework(c.Request.Context(), id)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": hw})
}

// SubmitHomework POST /homework/:id/submit
func (h *Handler) SubmitHomework(c *gin.Context) {
	var req SubmitHomeworkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	homeworkID := c.Param("id")
	userID := middleware.GetUserID(c)

	sub, err := h.service.SubmitHomework(c.Request.Context(), homeworkID, userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": sub})
}

// GradeHomework PUT /homework/submissions/:id/grade
func (h *Handler) GradeHomework(c *gin.Context) {
	var req GradeHomeworkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	submissionID := c.Param("id")
	userID := middleware.GetUserID(c)

	sub, err := h.service.GradeHomework(c.Request.Context(), submissionID, userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": sub})
}

// ─── Error Helper ───────────────────────────────────────────────

func handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrHomeworkNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "homework not found"}})
	case errors.Is(err, ErrSubmissionNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "submission not found"}})
	case errors.Is(err, ErrNotAuthorized):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{"message": "not authorized"}})
	case errors.Is(err, ErrAlreadySubmitted):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": "already submitted"}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
