package review

import (
	"time"

	"github.com/google/uuid"
)

// ─── Review ─────────────────────────────────────────────────────

type ReviewResponse struct {
	ID                 uuid.UUID  `json:"id"`
	SessionID          uuid.UUID  `json:"session_id"`
	ReviewerID         uuid.UUID  `json:"reviewer_id"`
	ReviewerName       string     `json:"reviewer_name"`
	TeacherID          uuid.UUID  `json:"teacher_id"`
	TeacherName        string     `json:"teacher_name"`
	OverallRating      int        `json:"overall_rating"`
	TeachingQuality    *int       `json:"teaching_quality,omitempty"`
	Communication      *int       `json:"communication,omitempty"`
	Punctuality        *int       `json:"punctuality,omitempty"`
	ContentQuality     *int       `json:"content_quality,omitempty"`
	ReviewText         *string    `json:"review_text,omitempty"`
	TeacherResponse    *string    `json:"teacher_response,omitempty"`
	TeacherRespondedAt *time.Time `json:"teacher_responded_at,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
}

type CreateReviewRequest struct {
	SessionID       uuid.UUID `json:"session_id" validate:"required"`
	TeacherID       uuid.UUID `json:"teacher_id" validate:"required"`
	OverallRating   int       `json:"overall_rating" validate:"required,min=1,max=5"`
	TeachingQuality *int      `json:"teaching_quality,omitempty" validate:"omitempty,min=1,max=5"`
	Communication   *int      `json:"communication,omitempty" validate:"omitempty,min=1,max=5"`
	Punctuality     *int      `json:"punctuality,omitempty" validate:"omitempty,min=1,max=5"`
	ContentQuality  *int      `json:"content_quality,omitempty" validate:"omitempty,min=1,max=5"`
	ReviewText      *string   `json:"review_text,omitempty"`
}

type RespondToReviewRequest struct {
	Response string `json:"response" validate:"required"`
}

// TeacherReviewSummary holds aggregate stats for a teacher's reviews.
type TeacherReviewSummary struct {
	TotalReviews    int     `json:"total_reviews"`
	AverageRating   float64 `json:"average_rating"`
	AverageTeaching float64 `json:"average_teaching,omitempty"`
	AverageComm     float64 `json:"average_communication,omitempty"`
	AveragePunct    float64 `json:"average_punctuality,omitempty"`
	AverageContent  float64 `json:"average_content,omitempty"`
}

type TeacherReviewsResponse struct {
	Summary TeacherReviewSummary `json:"summary"`
	Reviews []ReviewResponse     `json:"reviews"`
}
