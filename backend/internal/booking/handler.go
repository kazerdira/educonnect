package booking

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// CreateBookingRequest handles POST /api/v1/bookings
func (h *Handler) CreateBookingRequest(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Non autorisé"})
		return
	}
	userIDStr, ok := userID.(string)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Non autorisé"})
		return
	}

	userRole, exists := c.Get("user_role")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Non autorisé"})
		return
	}
	userRoleStr, ok := userRole.(string)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Non autorisé"})
		return
	}

	var req CreateBookingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Requête invalide: " + err.Error()})
		return
	}

	booking, err := h.service.CreateBookingRequest(c.Request.Context(), userIDStr, userRoleStr, req)
	if err != nil {
		switch {
		case errors.Is(err, ErrSlotNotAvailable):
			msg := err.Error()
			if i := strings.Index(msg, ": "); i >= 0 {
				msg = msg[i+2:]
			}
			c.JSON(http.StatusBadRequest, gin.H{"error": msg})
		case errors.Is(err, ErrAlreadyBooked):
			c.JSON(http.StatusConflict, gin.H{"error": "Ce créneau est déjà réservé"})
		default:
			slog.Error("create booking failed", "error", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erreur interne du serveur"})
		}
		return
	}

	c.JSON(http.StatusCreated, booking)
}

// GetBookingRequest handles GET /api/v1/bookings/:id
func (h *Handler) GetBookingRequest(c *gin.Context) {
	bookingID := c.Param("id")
	userID, _ := c.Get("user_id")

	booking, err := h.service.GetBookingRequest(c.Request.Context(), bookingID, userID.(string))
	if err != nil {
		if errors.Is(err, ErrBookingNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Demande non trouvée"})
			return
		}
		slog.Error("get booking failed", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Erreur interne du serveur"})
		return
	}

	c.JSON(http.StatusOK, booking)
}

// ListBookingRequests handles GET /api/v1/bookings
func (h *Handler) ListBookingRequests(c *gin.Context) {
	userID, _ := c.Get("user_id")

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	q := ListBookingsQuery{
		Status: c.Query("status"),
		Role:   c.DefaultQuery("role", "as_student"), // as_student or as_teacher
		Page:   page,
		Limit:  limit,
	}

	bookings, total, err := h.service.ListBookingRequests(c.Request.Context(), userID.(string), q)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"bookings": bookings,
		"total":    total,
		"page":     page,
		"limit":    limit,
	})
}

// AcceptBookingRequest handles PUT /api/v1/bookings/:id/accept
func (h *Handler) AcceptBookingRequest(c *gin.Context) {
	bookingID := c.Param("id")
	userID, _ := c.Get("user_id")

	var req AcceptBookingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Corps de requête invalide: le prix est requis. " + err.Error()})
		return
	}

	booking, err := h.service.AcceptBookingRequest(c.Request.Context(), bookingID, userID.(string), req)
	if err != nil {
		switch {
		case errors.Is(err, ErrBookingNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "Demande non trouvée"})
		case errors.Is(err, ErrUnauthorized):
			c.JSON(http.StatusForbidden, gin.H{"error": "Non autorisé"})
		case errors.Is(err, ErrInvalidStatus):
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cette demande ne peut plus être acceptée"})
		case errors.Is(err, ErrTimeConflict), errors.Is(err, ErrSessionFull):
			// Extract the friendly message after the sentinel prefix
			msg := err.Error()
			if idx := strings.Index(msg, ": "); idx >= 0 {
				msg = msg[idx+2:]
			}
			c.JSON(http.StatusConflict, gin.H{"error": msg})
		default:
			slog.Error("accept booking failed", "error", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erreur interne du serveur"})
		}
		return
	}

	c.JSON(http.StatusOK, booking)
}

// DeclineBookingRequest handles PUT /api/v1/bookings/:id/decline
func (h *Handler) DeclineBookingRequest(c *gin.Context) {
	bookingID := c.Param("id")
	userID, _ := c.Get("user_id")

	var req DeclineBookingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Un motif de refus est requis (min. 5 caractères)."})
		return
	}

	booking, err := h.service.DeclineBookingRequest(c.Request.Context(), bookingID, userID.(string), req)
	if err != nil {
		switch {
		case errors.Is(err, ErrBookingNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "Demande non trouvée"})
		case errors.Is(err, ErrUnauthorized):
			c.JSON(http.StatusForbidden, gin.H{"error": "Non autorisé"})
		case errors.Is(err, ErrInvalidStatus):
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cette demande ne peut plus être refusée"})
		default:
			slog.Error("decline booking failed", "error", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erreur interne du serveur"})
		}
		return
	}

	c.JSON(http.StatusOK, booking)
}

// CancelBookingRequest handles DELETE /api/v1/bookings/:id
func (h *Handler) CancelBookingRequest(c *gin.Context) {
	bookingID := c.Param("id")
	userID, _ := c.Get("user_id")

	err := h.service.CancelBookingRequest(c.Request.Context(), bookingID, userID.(string))
	if err != nil {
		if errors.Is(err, ErrBookingNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Demande non trouvée ou déjà traitée"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Demande annulée"})
}

// SendMessage handles POST /api/v1/bookings/:id/messages
func (h *Handler) SendMessage(c *gin.Context) {
	bookingID := c.Param("id")
	userID, _ := c.Get("user_id")

	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Message invalide: " + err.Error()})
		return
	}

	msg, err := h.service.SendMessage(c.Request.Context(), bookingID, userID.(string), req)
	if err != nil {
		switch {
		case errors.Is(err, ErrBookingNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "Demande non trouvée"})
		case errors.Is(err, ErrUnauthorized):
			c.JSON(http.StatusForbidden, gin.H{"error": "Non autorisé"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusCreated, msg)
}

// ListMessages handles GET /api/v1/bookings/:id/messages
func (h *Handler) ListMessages(c *gin.Context) {
	bookingID := c.Param("id")
	userID, _ := c.Get("user_id")

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	if limit < 1 || limit > 100 {
		limit = 50
	}

	q := ListMessagesQuery{
		Before: c.Query("before"),
		Limit:  limit,
	}

	messages, err := h.service.ListMessages(c.Request.Context(), bookingID, userID.(string), q)
	if err != nil {
		switch {
		case errors.Is(err, ErrBookingNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "Demande non trouvée"})
		case errors.Is(err, ErrUnauthorized):
			c.JSON(http.StatusForbidden, gin.H{"error": "Non autorisé"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"messages": messages})
}
