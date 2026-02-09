package parent

import (
	"errors"
	"net/http"

	"educonnect/internal/middleware"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Dashboard GET /parents/dashboard
func (h *Handler) Dashboard(c *gin.Context) {
	userID := middleware.GetUserID(c)
	dash, err := h.service.GetDashboard(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": dash})
}

// ListChildren GET /parents/children
func (h *Handler) ListChildren(c *gin.Context) {
	userID := middleware.GetUserID(c)
	children, err := h.service.ListChildren(c.Request.Context(), userID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": children})
}

// AddChild POST /parents/children
func (h *Handler) AddChild(c *gin.Context) {
	var req AddChildRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	userID := middleware.GetUserID(c)
	child, err := h.service.AddChild(c.Request.Context(), userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": child})
}

// GetChildProgress GET /parents/children/:childId/progress
func (h *Handler) GetChildProgress(c *gin.Context) {
	childID := c.Param("childId")
	userID := middleware.GetUserID(c)

	progress, err := h.service.GetChildProgress(c.Request.Context(), userID, childID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": progress})
}

// UpdateChild PUT /parents/children/:childId
func (h *Handler) UpdateChild(c *gin.Context) {
	childID := c.Param("childId")
	userID := middleware.GetUserID(c)

	var req UpdateChildRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	child, err := h.service.UpdateChild(c.Request.Context(), userID, childID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": child})
}

// RemoveChild DELETE /parents/children/:childId
func (h *Handler) RemoveChild(c *gin.Context) {
	childID := c.Param("childId")
	userID := middleware.GetUserID(c)

	err := h.service.RemoveChild(c.Request.Context(), userID, childID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "child removed"}})
}

func handleError(c *gin.Context, err error) {
	if errors.Is(err, ErrProfileNotFound) {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "parent profile not found"}})
		return
	}
	if errors.Is(err, ErrChildNotFound) {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "child not found"}})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
}
