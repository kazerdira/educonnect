package homework

import (
	"time"

	"github.com/google/uuid"
)

// ─── Homework ───────────────────────────────────────────────────

type HomeworkResponse struct {
	ID                 uuid.UUID  `json:"id"`
	TeacherID          uuid.UUID  `json:"teacher_id"`
	TeacherName        string     `json:"teacher_name"`
	Title              string     `json:"title"`
	Description        string     `json:"description,omitempty"`
	Instructions       string     `json:"instructions,omitempty"`
	FileURLs           []string   `json:"file_urls,omitempty"`
	SubjectID          *uuid.UUID `json:"subject_id,omitempty"`
	SubjectName        string     `json:"subject_name,omitempty"`
	LevelID            *uuid.UUID `json:"level_id,omitempty"`
	LevelName          string     `json:"level_name,omitempty"`
	Deadline           *time.Time `json:"deadline,omitempty"`
	AllowLate          bool       `json:"allow_late"`
	LatePenaltyPercent float64    `json:"late_penalty_percent"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type CreateHomeworkRequest struct {
	Title              string     `json:"title" validate:"required,min=3,max=255"`
	Description        string     `json:"description" validate:"omitempty,max=5000"`
	Instructions       string     `json:"instructions" validate:"omitempty,max=5000"`
	SubjectID          *uuid.UUID `json:"subject_id"`
	LevelID            *uuid.UUID `json:"level_id"`
	Deadline           *string    `json:"deadline"`
	AllowLate          bool       `json:"allow_late"`
	LatePenaltyPercent float64    `json:"late_penalty_percent" validate:"gte=0,lte=100"`
	StudentIDs         []string   `json:"student_ids"`
}

// ─── Submission ─────────────────────────────────────────────────

type SubmissionResponse struct {
	ID          uuid.UUID  `json:"id"`
	HomeworkID  uuid.UUID  `json:"homework_id"`
	StudentID   uuid.UUID  `json:"student_id"`
	StudentName string     `json:"student_name"`
	FileURLs    []string   `json:"file_urls,omitempty"`
	TextContent string     `json:"text_content,omitempty"`
	Grade       *float64   `json:"grade,omitempty"`
	MaxGrade    float64    `json:"max_grade"`
	Feedback    string     `json:"feedback,omitempty"`
	IsLate      bool       `json:"is_late"`
	SubmittedAt time.Time  `json:"submitted_at"`
	GradedAt    *time.Time `json:"graded_at,omitempty"`
}

type SubmitHomeworkRequest struct {
	TextContent string `json:"text_content" validate:"omitempty,max=10000"`
	// file_urls will be handled via multipart form or pre-uploaded URLs
	FileURLs []string `json:"file_urls"`
}

type GradeHomeworkRequest struct {
	Grade    float64 `json:"grade" validate:"gte=0"`
	MaxGrade float64 `json:"max_grade" validate:"gt=0"`
	Feedback string  `json:"feedback" validate:"omitempty,max=5000"`
}
