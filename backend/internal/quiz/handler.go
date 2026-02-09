package quiz

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

// CreateQuiz POST /quizzes
func (h *Handler) CreateQuiz(c *gin.Context) {
	var req CreateQuizRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	quiz, err := h.service.CreateQuiz(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "failed to create quiz"}})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": quiz})
}

// ListQuizzes GET /quizzes
func (h *Handler) ListQuizzes(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	userID := middleware.GetUserID(c)
	list, total, err := h.service.ListQuizzes(c.Request.Context(), userID, page, limit)
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

// GetQuiz GET /quizzes/:id
func (h *Handler) GetQuiz(c *gin.Context) {
	id := c.Param("id")
	quiz, err := h.service.GetQuiz(c.Request.Context(), id)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": quiz})
}

// AttemptQuiz POST /quizzes/:id/attempt
func (h *Handler) AttemptQuiz(c *gin.Context) {
	var req SubmitAttemptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	quizID := c.Param("id")
	userID := middleware.GetUserID(c)

	attempt, err := h.service.AttemptQuiz(c.Request.Context(), quizID, userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": attempt})
}

// QuizResults GET /quizzes/:id/results
func (h *Handler) QuizResults(c *gin.Context) {
	quizID := c.Param("id")
	userID := middleware.GetUserID(c)
	role := middleware.GetUserRole(c)

	results, err := h.service.GetQuizResults(c.Request.Context(), quizID, userID, role)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": results})
}

// ─── Error Helper ───────────────────────────────────────────────

func handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrQuizNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "quiz not found"}})
	case errors.Is(err, ErrAttemptNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "attempt not found"}})
	case errors.Is(err, ErrNotAuthorized):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{"message": "not authorized"}})
	case errors.Is(err, ErrMaxAttempts):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": "maximum attempts reached"}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
