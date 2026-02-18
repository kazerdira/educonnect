package sessionseries

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"educonnect/internal/middleware"
	"educonnect/internal/wallet"

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
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed", "details": err.Error()}})
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

// BrowseSeries GET /sessions/series/browse - public browsing for students/parents
func (h *Handler) BrowseSeries(c *gin.Context) {
	userID := middleware.GetUserID(c) // Get current user for enrollment status
	subjectID := c.Query("subject_id")
	levelID := c.Query("level_id")
	sessionType := c.Query("session_type")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	series, total, err := h.service.BrowseAvailableSeries(c.Request.Context(), userID, subjectID, levelID, sessionType, page, limit)
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
// Teacher: Invite Students
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

// ListRequests GET /sessions/series/:id/requests
func (h *Handler) ListRequests(c *gin.Context) {
	seriesID := c.Param("id")
	userID := middleware.GetUserID(c)
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	requests, total, err := h.service.ListSeriesRequests(c.Request.Context(), seriesID, userID, page, limit)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    requests,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// AcceptRequest PUT /sessions/series/:id/requests/:enrollmentId/accept
func (h *Handler) AcceptRequest(c *gin.Context) {
	seriesID := c.Param("id")
	enrollmentID := c.Param("enrollmentId")
	userID := middleware.GetUserID(c)

	enr, err := h.service.AcceptRequest(c.Request.Context(), seriesID, enrollmentID, userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": enr})
}

// DeclineRequest PUT /sessions/series/:id/requests/:enrollmentId/decline
func (h *Handler) DeclineRequest(c *gin.Context) {
	seriesID := c.Param("id")
	enrollmentID := c.Param("enrollmentId")
	userID := middleware.GetUserID(c)

	if err := h.service.DeclineRequest(c.Request.Context(), seriesID, enrollmentID, userID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "request declined"}})
}

// RemoveStudent DELETE /sessions/series/:id/students/:studentId
func (h *Handler) RemoveStudent(c *gin.Context) {
	seriesID := c.Param("id")
	studentID := c.Param("studentId")
	userID := middleware.GetUserID(c)

	if err := h.service.RemoveStudent(c.Request.Context(), seriesID, studentID, userID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "student removed"}})
}

// ═══════════════════════════════════════════════════════════════
// Student: Request to Join & Respond to Invitations
// ═══════════════════════════════════════════════════════════════

// RequestToJoin POST /sessions/series/:id/request
func (h *Handler) RequestToJoin(c *gin.Context) {
	seriesID := c.Param("id")
	userID := middleware.GetUserID(c)

	enr, err := h.service.RequestToJoin(c.Request.Context(), seriesID, userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": enr})
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

// ═══════════════════════════════════════════════════════════════
// Platform Fee Endpoints
// ═══════════════════════════════════════════════════════════════

// FinalizeSeries POST /sessions/series/:id/finalize
func (h *Handler) FinalizeSeries(c *gin.Context) {
	seriesID := c.Param("id")
	userID := middleware.GetUserID(c)

	series, err := h.service.FinalizeSeries(c.Request.Context(), seriesID, userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": series})
}

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

// ConfirmPayment POST /fees/:id/confirm
func (h *Handler) ConfirmPayment(c *gin.Context) {
	feeID := c.Param("id")
	var req ConfirmPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	fee, err := h.service.ConfirmPayment(c.Request.Context(), feeID, userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": fee})
}

// ═══════════════════════════════════════════════════════════════
// Admin: Verify Payment
// ═══════════════════════════════════════════════════════════════

// AdminVerifyPayment PUT /admin/fees/:id/verify
func (h *Handler) AdminVerifyPayment(c *gin.Context) {
	feeID := c.Param("id")
	userID := middleware.GetUserID(c)

	var req struct {
		Approved bool   `json:"approved"`
		Notes    string `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	fee, err := h.service.AdminVerifyPayment(c.Request.Context(), feeID, userID, req.Approved, req.Notes)
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

	// Get user name
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
	case errors.Is(err, ErrSeriesFull), errors.Is(err, ErrAlreadyEnrolled),
		errors.Is(err, ErrAlreadyRequested), errors.Is(err, ErrFeeAlreadyPaid),
		errors.Is(err, ErrAlreadyFinalized):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrFeeNotPaid):
		c.JSON(http.StatusPaymentRequired, gin.H{"success": false, "error": gin.H{
			"code":    "FEE_NOT_PAID",
			"message": err.Error(),
		}})
	case errors.Is(err, wallet.ErrInsufficientBalance):
		c.JSON(http.StatusPaymentRequired, gin.H{"success": false, "error": gin.H{
			"code":    "INSUFFICIENT_BALANCE",
			"message": err.Error(),
		}})
	case errors.Is(err, ErrNotEnrolled):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{
			"code":    "NOT_ENROLLED",
			"message": err.Error(),
		}})
	case errors.Is(err, ErrInvalidStatus), errors.Is(err, ErrInvalidDates),
		errors.Is(err, ErrNoEnrollments), errors.Is(err, ErrNoSessions),
		errors.Is(err, ErrNotFinalized):
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	default:
		// Log the actual error for debugging
		fmt.Printf("[ERROR] sessionseries: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
