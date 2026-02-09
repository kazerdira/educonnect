package course

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

// CreateCourse POST /courses
func (h *Handler) CreateCourse(c *gin.Context) {
	var req CreateCourseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	userID := middleware.GetUserID(c)
	course, err := h.service.CreateCourse(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "failed to create course"}})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": course})
}

// ListCourses GET /courses
func (h *Handler) ListCourses(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	teacherFilter := c.Query("teacher_id")
	courses, total, err := h.service.ListCourses(c.Request.Context(), teacherFilter, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    courses,
		"meta":    gin.H{"page": page, "limit": limit, "total": total, "has_more": int64(page*limit) < total},
	})
}

// GetCourse GET /courses/:id
func (h *Handler) GetCourse(c *gin.Context) {
	id := c.Param("id")
	course, err := h.service.GetCourse(c.Request.Context(), id)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": course})
}

// UpdateCourse PUT /courses/:id
func (h *Handler) UpdateCourse(c *gin.Context) {
	var req UpdateCourseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}

	courseID := c.Param("id")
	userID := middleware.GetUserID(c)

	course, err := h.service.UpdateCourse(c.Request.Context(), courseID, userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": course})
}

// DeleteCourse DELETE /courses/:id
func (h *Handler) DeleteCourse(c *gin.Context) {
	courseID := c.Param("id")
	userID := middleware.GetUserID(c)

	if err := h.service.DeleteCourse(c.Request.Context(), courseID, userID); err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"message": "course deleted"}})
}

// CreateChapter POST /courses/:id/chapters
func (h *Handler) CreateChapter(c *gin.Context) {
	var req CreateChapterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	courseID := c.Param("id")
	userID := middleware.GetUserID(c)

	chapter, err := h.service.CreateChapter(c.Request.Context(), courseID, userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": chapter})
}

// CreateLesson POST /courses/:id/chapters/:chapterId/lessons
func (h *Handler) CreateLesson(c *gin.Context) {
	var req CreateLessonRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": err.Error()}})
		return
	}
	if err := h.validate.Struct(req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": gin.H{"message": "validation failed"}})
		return
	}

	courseID := c.Param("id")
	chapterID := c.Param("chapterId")
	userID := middleware.GetUserID(c)

	lesson, err := h.service.CreateLesson(c.Request.Context(), courseID, chapterID, userID, req)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": lesson})
}

// UploadVideo POST /courses/:id/lessons/:lessonId/upload
func (h *Handler) UploadVideo(c *gin.Context) {
	courseID := c.Param("id")
	lessonID := c.Param("lessonId")
	userID := middleware.GetUserID(c)

	file, header, err := c.Request.FormFile("video")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": gin.H{"message": "video file required"}})
		return
	}
	defer file.Close()

	resp, err := h.service.UploadVideo(c.Request.Context(), courseID, lessonID, userID, file, header.Size, header.Header.Get("Content-Type"))
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": resp})
}

// EnrollStudent POST /courses/:id/enroll
func (h *Handler) EnrollStudent(c *gin.Context) {
	courseID := c.Param("id")
	userID := middleware.GetUserID(c)

	enrollment, err := h.service.EnrollStudent(c.Request.Context(), courseID, userID)
	if err != nil {
		handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": enrollment})
}

// ─── Error Helper ───────────────────────────────────────────────

func handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrCourseNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "course not found"}})
	case errors.Is(err, ErrChapterNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "chapter not found"}})
	case errors.Is(err, ErrLessonNotFound):
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": gin.H{"message": "lesson not found"}})
	case errors.Is(err, ErrNotAuthorized):
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": gin.H{"message": "not authorized"}})
	case errors.Is(err, ErrAlreadyEnrolled):
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": gin.H{"message": "already enrolled"}})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": gin.H{"message": "internal server error"}})
	}
}
