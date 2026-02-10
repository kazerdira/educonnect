package sessionseries

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

// ═══════════════════════════════════════════════════════════════
// Series Endpoints
// ═══════════════════════════════════════════════════════════════

// CreateSeries POST /sessions/series
func (h *Handler) CreateSeries(c *gin.Context) {
	var req CreateSeriesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	series, err := h.service.CreateSeries(c.Request.Context(), userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": series})
}

// ListSeries GET /sessions/series
func (h *Handler) ListSeries(c *gin.Context) {
	userID := middleware.GetUserID(c)
	status := c.Query("status")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	series, total, err := h.service.ListTeacherSeries(c.Request.Context(), userID, status, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    series,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// GetSeries GET /sessions/series/:id
func (h *Handler) GetSeries(c *gin.Context) {
	seriesID := c.Param("id")
	userID := middleware.GetUserID(c)
	series, err := h.service.GetSeries(c.Request.Context(), seriesID, userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": series})
}

// AddSessions POST /sessions/series/:id/sessions
func (h *Handler) AddSessions(c *gin.Context) {
	var req AddSessionsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	seriesID := c.Param("id")
	userID := middleware.GetUserID(c)
	series, err := h.service.AddSessions(c.Request.Context(), seriesID, userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": series})
}

// ═══════════════════════════════════════════════════════════════
// Invitation Endpoints
// ═══════════════════════════════════════════════════════════════

// InviteStudents POST /sessions/series/:id/invite
func (h *Handler) InviteStudents(c *gin.Context) {
	var req InviteStudentsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	seriesID := c.Param("id")
	userID := middleware.GetUserID(c)
	invitations, err := h.service.InviteStudents(c.Request.Context(), seriesID, userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": invitations})
}

// ListInvitations GET /invitations
func (h *Handler) ListInvitations(c *gin.Context) {
	userID := middleware.GetUserID(c)
	status := c.Query("status")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	invitations, total, err := h.service.ListMyInvitations(c.Request.Context(), userID, status, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    invitations,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// AcceptInvitation PUT /invitations/:id/accept
func (h *Handler) AcceptInvitation(c *gin.Context) {
	enrollmentID := c.Param("id")
	userID := middleware.GetUserID(c)
	inv, err := h.service.AcceptInvitation(c.Request.Context(), enrollmentID, userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": inv})
}

// DeclineInvitation PUT /invitations/:id/decline
func (h *Handler) DeclineInvitation(c *gin.Context) {
	enrollmentID := c.Param("id")
	userID := middleware.GetUserID(c)
	if err := h.service.DeclineInvitation(c.Request.Context(), enrollmentID, userID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "invitation declined"}})
}

// RemoveStudent DELETE /sessions/series/:id/students/:studentId
func (h *Handler) RemoveStudent(c *gin.Context) {
	seriesID := c.Param("id")
	studentID := c.Param("studentId")
	userID := middleware.GetUserID(c)
	if err := h.service.RemoveStudentFromSeries(c.Request.Context(), seriesID, userID, studentID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "student removed"}})
}

// ═══════════════════════════════════════════════════════════════
// Platform Fee Endpoints
// ═══════════════════════════════════════════════════════════════

// ListPendingFees GET /fees/pending
func (h *Handler) ListPendingFees(c *gin.Context) {
	userID := middleware.GetUserID(c)
	fees, err := h.service.ListPendingFees(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": fees})
}

// ConfirmFeePayment POST /fees/:id/confirm
func (h *Handler) ConfirmFeePayment(c *gin.Context) {
	feeID := c.Param("id")
	var req ConfirmFeePaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	fee, err := h.service.ConfirmFeePayment(c.Request.Context(), feeID, userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": fee})
}

// ═══════════════════════════════════════════════════════════════
// Join Session (with access control)
// ═══════════════════════════════════════════════════════════════

// JoinSession POST /sessions/:id/join
func (h *Handler) JoinSession(c *gin.Context) {
	sessionID := c.Param("id")
	userID := middleware.GetUserID(c)
	role := middleware.GetUserRole(c)
	userName := "User-" + userID[:8]

	resp, err := h.service.JoinSession(c.Request.Context(), sessionID, userID, userName, role)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": resp})
}

// ═══════════════════════════════════════════════════════════════
// Error Handler
// ═══════════════════════════════════════════════════════════════

func respondError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrSeriesNotFound), errors.Is(err, ErrSessionNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrEnrollmentNotFound), errors.Is(err, ErrFeeNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrNotAuthorized):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrSeriesFull), errors.Is(err, ErrAlreadyInvited),
		errors.Is(err, ErrAlreadyAccepted), errors.Is(err, ErrFeeAlreadyPaid):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrFeeNotPaid):
		c.JSON(http.StatusPaymentRequired, gin.H{"success": false, "error": gin.H{
			"code":    "FEE_NOT_PAID",
			"message": err.Error(),
		}})
	case errors.Is(err, ErrNotEnrolled):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{
			"code":    "NOT_ENROLLED",
			"message": err.Error(),
		}})
	case errors.Is(err, ErrInvalidStatus), errors.Is(err, ErrInvalidDates):
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
