package notification

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

// ListNotifications GET /notifications
func (h *Handler) ListNotifications(c *gin.Context) {
	userID := middleware.GetUserID(c)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	unreadOnly := c.DefaultQuery("unread_only", "false") == "true"

	notifications, total, err := h.service.ListNotifications(c.Request.Context(), userID, limit, offset, unreadOnly)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    notifications,
		"meta":    gin.H{"total": total, "limit": limit, "offset": offset},
	})
}

// MarkNotificationRead PUT /notifications/:id/read
func (h *Handler) MarkNotificationRead(c *gin.Context) {
	userID := middleware.GetUserID(c)
	notifID := c.Param("id")

	if err := h.service.MarkRead(c.Request.Context(), userID, notifID); err != nil {
		if errors.Is(err, ErrNotificationNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "notification marked as read"}})
}

// UpdateNotifPreferences PUT /notifications/preferences
func (h *Handler) UpdateNotifPreferences(c *gin.Context) {
	userID := middleware.GetUserID(c)
	var req UpdatePreferencesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	prefs, err := h.service.UpdatePreferences(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": prefs})
}
