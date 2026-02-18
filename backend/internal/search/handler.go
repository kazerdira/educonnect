package search

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// SearchTeachers GET /search/teachers?q=...&level=...&subject=...
func (h *Handler) SearchTeachers(c *gin.Context) {
	var req SearchRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if req.Query == "" && req.Subject == "" && req.Level == "" && req.Wilaya == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "Veuillez saisir un texte ou sélectionner un filtre"}})
		return
	}

	result, err := h.service.SearchTeachers(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "search failed"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result.Hits,
		"meta": gin.H{
			"total":              result.TotalHits,
			"page":               result.Page,
			"limit":              result.Limit,
			"processing_time_ms": result.ProcessingTimeMs,
		},
	})
}

// SearchCourses GET /search/courses?q=...&level=...&subject=...
func (h *Handler) SearchCourses(c *gin.Context) {
	var req SearchRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if req.Query == "" && req.Subject == "" && req.Level == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "Veuillez saisir un texte ou sélectionner un filtre"}})
		return
	}

	result, err := h.service.SearchCourses(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "search failed"}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result.Hits,
		"meta": gin.H{
			"total":              result.TotalHits,
			"page":               result.Page,
			"limit":              result.Limit,
			"processing_time_ms": result.ProcessingTimeMs,
		},
	})
}
