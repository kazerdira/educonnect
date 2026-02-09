package quiz

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// ─── Quiz ───────────────────────────────────────────────────────

type QuizResponse struct {
	ID                 uuid.UUID       `json:"id"`
	TeacherID          uuid.UUID       `json:"teacher_id"`
	TeacherName        string          `json:"teacher_name"`
	Title              string          `json:"title"`
	Description        string          `json:"description,omitempty"`
	SubjectID          *uuid.UUID      `json:"subject_id,omitempty"`
	SubjectName        string          `json:"subject_name,omitempty"`
	LevelID            *uuid.UUID      `json:"level_id,omitempty"`
	LevelName          string          `json:"level_name,omitempty"`
	TimeLimitMinutes   *int            `json:"time_limit_minutes,omitempty"`
	RandomizeQuestions bool            `json:"randomize_questions"`
	RandomizeOptions   bool            `json:"randomize_options"`
	ShowAnswersAfter   bool            `json:"show_answers_after"`
	MaxAttempts        int             `json:"max_attempts"`
	Questions          json.RawMessage `json:"questions"`
	QuestionCount      int             `json:"question_count"`
	CreatedAt          time.Time       `json:"created_at"`
	UpdatedAt          time.Time       `json:"updated_at"`
}

type CreateQuizRequest struct {
	Title              string          `json:"title" validate:"required,min=3,max=255"`
	Description        string          `json:"description" validate:"omitempty,max=5000"`
	SubjectID          *uuid.UUID      `json:"subject_id"`
	LevelID            *uuid.UUID      `json:"level_id"`
	TimeLimitMinutes   *int            `json:"time_limit_minutes" validate:"omitempty,min=1"`
	RandomizeQuestions bool            `json:"randomize_questions"`
	RandomizeOptions   bool            `json:"randomize_options"`
	ShowAnswersAfter   bool            `json:"show_answers_after"`
	MaxAttempts        int             `json:"max_attempts" validate:"gte=1"`
	Questions          json.RawMessage `json:"questions" validate:"required"`
}

// ─── Attempt ────────────────────────────────────────────────────

type AttemptResponse struct {
	ID          uuid.UUID       `json:"id"`
	QuizID      uuid.UUID       `json:"quiz_id"`
	StudentID   uuid.UUID       `json:"student_id"`
	StudentName string          `json:"student_name"`
	Answers     json.RawMessage `json:"answers,omitempty"`
	Score       *float64        `json:"score,omitempty"`
	MaxScore    *float64        `json:"max_score,omitempty"`
	IsGraded    bool            `json:"is_graded"`
	StartedAt   time.Time       `json:"started_at"`
	CompletedAt *time.Time      `json:"completed_at,omitempty"`
}

type SubmitAttemptRequest struct {
	Answers json.RawMessage `json:"answers" validate:"required"`
}

// ─── Results ────────────────────────────────────────────────────

type QuizResultsResponse struct {
	QuizID        uuid.UUID         `json:"quiz_id"`
	QuizTitle     string            `json:"quiz_title"`
	TotalAttempts int               `json:"total_attempts"`
	AverageScore  float64           `json:"average_score"`
	Attempts      []AttemptResponse `json:"attempts"`
}
