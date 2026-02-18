package wallet

import (
	"errors"
	"fmt"
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
// Teacher Endpoints
// ═══════════════════════════════════════════════════════════════

// GetWallet GET /wallet
func (h *Handler) GetWallet(c *gin.Context) {
	userID := middleware.GetUserID(c)
	w, err := h.service.GetOrCreateWallet(c.Request.Context(), userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": w})
}

// BuyCredits POST /wallet/buy
func (h *Handler) BuyCredits(c *gin.Context) {
	var req BuyCreditsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed", "details": err.Error()}})
		return
	}

	userID := middleware.GetUserID(c)
	tx, err := h.service.BuyCredits(c.Request.Context(), userID, req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": tx})
}

// ListTransactions GET /wallet/transactions
func (h *Handler) ListTransactions(c *gin.Context) {
	userID := middleware.GetUserID(c)
	txType := c.Query("type") // purchase, star_deduction, refund
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	txs, total, err := h.service.ListTransactions(c.Request.Context(), userID, txType, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    txs,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// ListPackages GET /wallet/packages
func (h *Handler) ListPackages(c *gin.Context) {
	pkgs, err := h.service.ListPackages(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": pkgs})
}

// ═══════════════════════════════════════════════════════════════
// Admin Endpoints
// ═══════════════════════════════════════════════════════════════

// AdminListPendingPurchases GET /admin/wallet/purchases
func (h *Handler) AdminListPendingPurchases(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	txs, total, err := h.service.AdminListPendingPurchases(c.Request.Context(), page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    txs,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// AdminApprovePurchase PUT /admin/wallet/purchases/:id/verify
func (h *Handler) AdminApprovePurchase(c *gin.Context) {
	txID := c.Param("id")
	adminID := middleware.GetUserID(c)

	var req AdminApprovePurchaseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	tx, err := h.service.AdminApprovePurchase(c.Request.Context(), txID, adminID, req.Approved, req.Notes)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": tx})
}

// ═══════════════════════════════════════════════════════════════
// Error Handler
// ═══════════════════════════════════════════════════════════════

func respondError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrWalletNotFound), errors.Is(err, ErrTransactionNotFound), errors.Is(err, ErrPackageNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrInsufficientBalance):
		c.JSON(http.StatusPaymentRequired, gin.H{"success": false, "error": gin.H{
			"code":    "INSUFFICIENT_BALANCE",
			"message": err.Error(),
		}})
	case errors.Is(err, ErrPackageInactive), errors.Is(err, ErrAlreadyProcessed), errors.Is(err, ErrNotPendingPurchase):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	case errors.Is(err, ErrRefundNotEligible):
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{
			"code":    "REFUND_NOT_ELIGIBLE",
			"message": err.Error(),
		}})
	case errors.Is(err, ErrEnrollmentNotAccepted):
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
	default:
		fmt.Printf("[ERROR] wallet: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
