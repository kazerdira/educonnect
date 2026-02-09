package session

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

// CreateSession POST /sessions
func (h *Handler) CreateSession(c *gin.Context) {
	var req CreateSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	userID := middleware.GetUserID(c)
	sess, err := h.service.CreateSession(c.Request.Context(), userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": sess})
}

// GetSession GET /sessions/:id
func (h *Handler) GetSession(c *gin.Context) {
	id := c.Param("id")
	sess, err := h.service.GetSession(c.Request.Context(), id)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": sess})
}

// ListSessions GET /sessions
func (h *Handler) ListSessions(c *gin.Context) {
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

	q := ListSessionsQuery{
		Page:   page,
		Limit:  limit,
		Status: c.Query("status"),
	}

	sessions, total, err := h.service.ListSessions(c.Request.Context(), userID, role, q)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    sessions,
		"meta": gin.H{
			"page":     page,
			"limit":    limit,
			"total":    total,
			"has_more": int64(page*limit) < total,
		},
	})
}

// JoinSession POST /sessions/:id/join
func (h *Handler) JoinSession(c *gin.Context) {
	sessionID := c.Param("id")
	userID := middleware.GetUserID(c)
	role := middleware.GetUserRole(c)

	// Get user name from context or a simple fallback
	userName := "User-" + userID[:8]

	resp, err := h.service.JoinSession(c.Request.Context(), sessionID, userID, userName, role)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": resp})
}

// CancelSession POST /sessions/:id/cancel
func (h *Handler) CancelSession(c *gin.Context) {
	var req CancelSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	sessionID := c.Param("id")
	userID := middleware.GetUserID(c)

	err := h.service.CancelSession(c.Request.Context(), sessionID, userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "session cancelled"}})
}

// RescheduleSession PUT /sessions/:id/reschedule
func (h *Handler) RescheduleSession(c *gin.Context) {
	var req RescheduleSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	sessionID := c.Param("id")
	userID := middleware.GetUserID(c)

	sess, err := h.service.RescheduleSession(c.Request.Context(), sessionID, userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": sess})
}

// EndSession POST /sessions/:id/end
func (h *Handler) EndSession(c *gin.Context) {
	sessionID := c.Param("id")
	userID := middleware.GetUserID(c)

	err := h.service.EndSession(c.Request.Context(), sessionID, userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "session ended"}})
}

func respondError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrSessionNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "session not found"}})
	case errors.Is(err, ErrUnauthorized):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{"message": "unauthorized"}})
	case errors.Is(err, ErrInvalidStatus):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": "session status does not allow this action"}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
