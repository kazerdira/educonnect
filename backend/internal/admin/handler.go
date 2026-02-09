package admin

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

// ─── Users ──────────────────────────────────────────────────────

// ListUsers GET /admin/users
func (h *Handler) ListUsers(c *gin.Context) {
	role := c.DefaultQuery("role", "")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	users, total, err := h.service.ListUsers(c.Request.Context(), role, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    users,
		"meta":    gin.H{"total": total, "limit": limit, "offset": offset},
	})
}

// GetUser GET /admin/users/:id
func (h *Handler) GetUser(c *gin.Context) {
	userID := c.Param("id")

	user, err := h.service.GetUser(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": user})
}

// SuspendUser PUT /admin/users/:id/suspend
func (h *Handler) SuspendUser(c *gin.Context) {
	userID := c.Param("id")

	if err := h.service.SuspendUser(c.Request.Context(), userID); err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "user suspended"}})
}

// ─── Verifications ──────────────────────────────────────────────

// ListVerifications GET /admin/verifications
func (h *Handler) ListVerifications(c *gin.Context) {
	status := c.DefaultQuery("status", "")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	vfs, total, err := h.service.ListVerifications(c.Request.Context(), status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    vfs,
		"meta":    gin.H{"total": total, "limit": limit, "offset": offset},
	})
}

// ApproveTeacher PUT /admin/verifications/:id/approve
func (h *Handler) ApproveTeacher(c *gin.Context) {
	verifyID := c.Param("id")

	if err := h.service.ApproveTeacher(c.Request.Context(), verifyID); err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "teacher approved"}})
}

// RejectTeacher PUT /admin/verifications/:id/reject
func (h *Handler) RejectTeacher(c *gin.Context) {
	verifyID := c.Param("id")

	if err := h.service.RejectTeacher(c.Request.Context(), verifyID); err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "teacher rejected"}})
}

// ─── Transactions ───────────────────────────────────────────────

// ListTransactions GET /admin/transactions
func (h *Handler) ListTransactions(c *gin.Context) {
	status := c.DefaultQuery("status", "")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	txns, total, err := h.service.ListTransactions(c.Request.Context(), status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    txns,
		"meta":    gin.H{"total": total, "limit": limit, "offset": offset},
	})
}

// ─── Disputes ───────────────────────────────────────────────────

// ListDisputes GET /admin/disputes
func (h *Handler) ListDisputes(c *gin.Context) {
	status := c.DefaultQuery("status", "")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	disputes, total, err := h.service.ListDisputes(c.Request.Context(), status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    disputes,
		"meta":    gin.H{"total": total, "limit": limit, "offset": offset},
	})
}

// ResolveDispute PUT /admin/disputes/:id/resolve
func (h *Handler) ResolveDispute(c *gin.Context) {
	disputeID := c.Param("id")
	var req ResolveDisputeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	adminID := middleware.GetUserID(c)
	dispute, err := h.service.ResolveDispute(c.Request.Context(), adminID, disputeID, req)
	if err != nil {
		handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": dispute})
}

// ─── Analytics ──────────────────────────────────────────────────

// AnalyticsOverview GET /admin/analytics/overview
func (h *Handler) AnalyticsOverview(c *gin.Context) {
	overview, err := h.service.AnalyticsOverview(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": overview})
}

// AnalyticsRevenue GET /admin/analytics/revenue
func (h *Handler) AnalyticsRevenue(c *gin.Context) {
	revenue, err := h.service.AnalyticsRevenue(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": revenue})
}

// ─── Config ─────────────────────────────────────────────────────

// UpdateSubjects PUT /admin/config/subjects
func (h *Handler) UpdateSubjects(c *gin.Context) {
	var req UpdateSubjectsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	subjects, err := h.service.UpdateSubjects(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": subjects})
}

// UpdateLevels PUT /admin/config/levels
func (h *Handler) UpdateLevels(c *gin.Context) {
	var req UpdateLevelsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	levels, err := h.service.UpdateLevels(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": levels})
}

func handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrUserNotFound), errors.Is(err, ErrDisputeNotFound), errors.Is(err, ErrVerifyNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
