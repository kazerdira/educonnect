package course

import (
	"time"

	"github.com/google/uuid"
)

// ─── Course ─────────────────────────────────────────────────────

type CourseResponse struct {
	ID              uuid.UUID         `json:"id"`
	TeacherID       uuid.UUID         `json:"teacher_id"`
	TeacherName     string            `json:"teacher_name"`
	Title           string            `json:"title"`
	Description     string            `json:"description,omitempty"`
	SubjectID       *uuid.UUID        `json:"subject_id,omitempty"`
	SubjectName     string            `json:"subject_name,omitempty"`
	LevelID         *uuid.UUID        `json:"level_id,omitempty"`
	LevelName       string            `json:"level_name,omitempty"`
	Price           float64           `json:"price"`
	IsPublished     bool              `json:"is_published"`
	ThumbnailURL    string            `json:"thumbnail_url,omitempty"`
	EnrollmentCount int               `json:"enrollment_count"`
	Chapters        []ChapterResponse `json:"chapters,omitempty"`
	CreatedAt       time.Time         `json:"created_at"`
	UpdatedAt       time.Time         `json:"updated_at"`
}

type CreateCourseRequest struct {
	Title       string     `json:"title" validate:"required,min=3,max=255"`
	Description string     `json:"description" validate:"omitempty,max=5000"`
	SubjectID   *uuid.UUID `json:"subject_id"`
	LevelID     *uuid.UUID `json:"level_id"`
	Price       float64    `json:"price" validate:"gte=0"`
	IsPublished bool       `json:"is_published"`
}

type UpdateCourseRequest struct {
	Title        *string    `json:"title" validate:"omitempty,min=3,max=255"`
	Description  *string    `json:"description" validate:"omitempty,max=5000"`
	SubjectID    *uuid.UUID `json:"subject_id"`
	LevelID      *uuid.UUID `json:"level_id"`
	Price        *float64   `json:"price" validate:"omitempty,gte=0"`
	IsPublished  *bool      `json:"is_published"`
	ThumbnailURL *string    `json:"thumbnail_url"`
}

// ─── Chapter ────────────────────────────────────────────────────

type ChapterResponse struct {
	ID        uuid.UUID        `json:"id"`
	CourseID  uuid.UUID        `json:"course_id"`
	Title     string           `json:"title"`
	Order     int              `json:"order"`
	Lessons   []LessonResponse `json:"lessons,omitempty"`
	CreatedAt time.Time        `json:"created_at"`
}

type CreateChapterRequest struct {
	Title string `json:"title" validate:"required,min=1,max=255"`
	Order int    `json:"order" validate:"gte=0"`
}

// ─── Lesson ─────────────────────────────────────────────────────

type LessonResponse struct {
	ID          uuid.UUID `json:"id"`
	ChapterID   uuid.UUID `json:"chapter_id"`
	Title       string    `json:"title"`
	Description string    `json:"description,omitempty"`
	VideoURL    string    `json:"video_url,omitempty"`
	Duration    int       `json:"duration"`
	Order       int       `json:"order"`
	IsPreview   bool      `json:"is_preview"`
	CreatedAt   time.Time `json:"created_at"`
}

type CreateLessonRequest struct {
	Title       string `json:"title" validate:"required,min=1,max=255"`
	Description string `json:"description" validate:"omitempty,max=5000"`
	Order       int    `json:"order" validate:"gte=0"`
	IsPreview   bool   `json:"is_preview"`
}

// ─── Enrollment ─────────────────────────────────────────────────

type EnrollmentResponse struct {
	ID              uuid.UUID  `json:"id"`
	CourseID        uuid.UUID  `json:"course_id"`
	CourseTitle     string     `json:"course_title"`
	StudentID       uuid.UUID  `json:"student_id"`
	ProgressPercent float64    `json:"progress_percent"`
	LastLessonID    *uuid.UUID `json:"last_lesson_id,omitempty"`
	EnrolledAt      time.Time  `json:"enrolled_at"`
}

// ─── Upload ─────────────────────────────────────────────────────

type UploadVideoResponse struct {
	VideoURL string `json:"video_url"`
}
