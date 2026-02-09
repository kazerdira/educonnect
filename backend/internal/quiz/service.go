package quiz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrQuizNotFound    = errors.New("quiz not found")
	ErrAttemptNotFound = errors.New("attempt not found")
	ErrNotAuthorized   = errors.New("not authorized")
	ErrMaxAttempts     = errors.New("max attempts reached")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ─── Quiz CRUD ──────────────────────────────────────────────────

func (s *Service) CreateQuiz(ctx context.Context, teacherID string, req CreateQuizRequest) (*QuizResponse, error) {
	tid, _ := uuid.Parse(teacherID)
	id := uuid.New()

	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO quizzes (id, teacher_id, title, description, subject_id, level_id,
		 time_limit_minutes, randomize_questions, randomize_options, show_answers_after, max_attempts, questions)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
		id, tid, req.Title, req.Description, req.SubjectID, req.LevelID,
		req.TimeLimitMinutes, req.RandomizeQuestions, req.RandomizeOptions,
		req.ShowAnswersAfter, req.MaxAttempts, req.Questions,
	)
	if err != nil {
		return nil, fmt.Errorf("create quiz: %w", err)
	}
	return s.GetQuiz(ctx, id.String())
}

func (s *Service) GetQuiz(ctx context.Context, quizID string) (*QuizResponse, error) {
	qid, _ := uuid.Parse(quizID)
	q := &QuizResponse{}

	var subjectID, levelID *uuid.UUID
	var subjectName, levelName *string

	err := s.db.Pool.QueryRow(ctx,
		`SELECT qz.id, qz.teacher_id, CONCAT(u.first_name,' ',u.last_name),
		        qz.title, COALESCE(qz.description,''), qz.subject_id, qz.level_id,
		        s.name_fr, l.name,
		        qz.time_limit_minutes, qz.randomize_questions, qz.randomize_options,
		        qz.show_answers_after, qz.max_attempts, qz.questions,
		        qz.created_at, qz.updated_at
		 FROM quizzes qz
		 JOIN users u ON u.id = qz.teacher_id
		 LEFT JOIN subjects s ON s.id = qz.subject_id
		 LEFT JOIN levels l ON l.id = qz.level_id
		 WHERE qz.id = $1`, qid,
	).Scan(
		&q.ID, &q.TeacherID, &q.TeacherName,
		&q.Title, &q.Description, &subjectID, &levelID,
		&subjectName, &levelName,
		&q.TimeLimitMinutes, &q.RandomizeQuestions, &q.RandomizeOptions,
		&q.ShowAnswersAfter, &q.MaxAttempts, &q.Questions,
		&q.CreatedAt, &q.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrQuizNotFound
		}
		return nil, fmt.Errorf("get quiz: %w", err)
	}

	q.SubjectID = subjectID
	q.LevelID = levelID
	if subjectName != nil {
		q.SubjectName = *subjectName
	}
	if levelName != nil {
		q.LevelName = *levelName
	}

	// Count questions
	var arr []json.RawMessage
	if json.Unmarshal(q.Questions, &arr) == nil {
		q.QuestionCount = len(arr)
	}

	return q, nil
}

func (s *Service) ListQuizzes(ctx context.Context, teacherID string, page, limit int) ([]QuizResponse, int64, error) {
	offset := (page - 1) * limit
	tid, _ := uuid.Parse(teacherID)

	var total int64
	_ = s.db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM quizzes WHERE teacher_id = $1`, tid).Scan(&total)

	rows, err := s.db.Pool.Query(ctx,
		`SELECT qz.id, qz.teacher_id, CONCAT(u.first_name,' ',u.last_name),
		        qz.title, COALESCE(qz.description,''), qz.subject_id, qz.level_id,
		        s.name_fr, l.name,
		        qz.time_limit_minutes, qz.randomize_questions, qz.randomize_options,
		        qz.show_answers_after, qz.max_attempts, qz.questions,
		        qz.created_at, qz.updated_at
		 FROM quizzes qz
		 JOIN users u ON u.id = qz.teacher_id
		 LEFT JOIN subjects s ON s.id = qz.subject_id
		 LEFT JOIN levels l ON l.id = qz.level_id
		 WHERE qz.teacher_id = $3
		 ORDER BY qz.created_at DESC LIMIT $1 OFFSET $2`, limit, offset, tid)
	if err != nil {
		return nil, 0, fmt.Errorf("list quizzes: %w", err)
	}
	defer rows.Close()

	var list []QuizResponse
	for rows.Next() {
		var q QuizResponse
		var subjectID, levelID *uuid.UUID
		var subjectName, levelName *string
		if err := rows.Scan(
			&q.ID, &q.TeacherID, &q.TeacherName,
			&q.Title, &q.Description, &subjectID, &levelID,
			&subjectName, &levelName,
			&q.TimeLimitMinutes, &q.RandomizeQuestions, &q.RandomizeOptions,
			&q.ShowAnswersAfter, &q.MaxAttempts, &q.Questions,
			&q.CreatedAt, &q.UpdatedAt,
		); err != nil {
			continue
		}
		q.SubjectID = subjectID
		q.LevelID = levelID
		if subjectName != nil {
			q.SubjectName = *subjectName
		}
		if levelName != nil {
			q.LevelName = *levelName
		}
		var arr []json.RawMessage
		if json.Unmarshal(q.Questions, &arr) == nil {
			q.QuestionCount = len(arr)
		}
		list = append(list, q)
	}
	if list == nil {
		list = []QuizResponse{}
	}
	return list, total, nil
}

// ─── Attempt ────────────────────────────────────────────────────

func (s *Service) AttemptQuiz(ctx context.Context, quizID, studentID string, req SubmitAttemptRequest) (*AttemptResponse, error) {
	qid, _ := uuid.Parse(quizID)
	sid, _ := uuid.Parse(studentID)

	// Check quiz exists and get max_attempts
	var maxAttempts int
	var questions json.RawMessage
	err := s.db.Pool.QueryRow(ctx, `SELECT max_attempts, questions FROM quizzes WHERE id = $1`, qid).Scan(&maxAttempts, &questions)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrQuizNotFound
		}
		return nil, err
	}

	// Count existing attempts
	var attemptCount int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM quiz_attempts WHERE quiz_id = $1 AND student_id = $2`, qid, sid).Scan(&attemptCount)
	if attemptCount >= maxAttempts {
		return nil, ErrMaxAttempts
	}

	// Auto-grade: simple scoring for multiple-choice
	score, maxScore := autoGrade(questions, req.Answers)

	id := uuid.New()
	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO quiz_attempts (id, quiz_id, student_id, answers, score, max_score, started_at, completed_at, is_graded)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$7,$8)`,
		id, qid, sid, req.Answers, score, maxScore, now, true,
	)
	if err != nil {
		return nil, fmt.Errorf("submit attempt: %w", err)
	}

	return s.getAttempt(ctx, id)
}

func (s *Service) GetQuizResults(ctx context.Context, quizID, userID, role string) (*QuizResultsResponse, error) {
	qid, _ := uuid.Parse(quizID)
	uid, _ := uuid.Parse(userID)

	// Get quiz title
	var title string
	var teacherID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT title, teacher_id FROM quizzes WHERE id = $1`, qid).Scan(&title, &teacherID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrQuizNotFound
		}
		return nil, err
	}

	// Teachers see all attempts; students see only their own
	var filterSQL string
	args := []interface{}{qid}
	if role == "teacher" {
		if teacherID != uid {
			return nil, ErrNotAuthorized
		}
		filterSQL = ""
	} else {
		filterSQL = " AND qa.student_id = $2"
		args = append(args, uid)
	}

	q := fmt.Sprintf(
		`SELECT qa.id, qa.quiz_id, qa.student_id, CONCAT(u.first_name,' ',u.last_name),
		        qa.answers, qa.score, qa.max_score, qa.is_graded, qa.started_at, qa.completed_at
		 FROM quiz_attempts qa
		 JOIN users u ON u.id = qa.student_id
		 WHERE qa.quiz_id = $1%s
		 ORDER BY qa.started_at DESC`, filterSQL)

	rows, err := s.db.Pool.Query(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("quiz results: %w", err)
	}
	defer rows.Close()

	var attempts []AttemptResponse
	var totalScore float64
	for rows.Next() {
		var a AttemptResponse
		if err := rows.Scan(
			&a.ID, &a.QuizID, &a.StudentID, &a.StudentName,
			&a.Answers, &a.Score, &a.MaxScore, &a.IsGraded,
			&a.StartedAt, &a.CompletedAt,
		); err != nil {
			continue
		}
		if a.Score != nil {
			totalScore += *a.Score
		}
		attempts = append(attempts, a)
	}
	if attempts == nil {
		attempts = []AttemptResponse{}
	}

	avg := float64(0)
	if len(attempts) > 0 {
		avg = totalScore / float64(len(attempts))
	}

	return &QuizResultsResponse{
		QuizID:        qid,
		QuizTitle:     title,
		TotalAttempts: len(attempts),
		AverageScore:  avg,
		Attempts:      attempts,
	}, nil
}

func (s *Service) getAttempt(ctx context.Context, id uuid.UUID) (*AttemptResponse, error) {
	a := &AttemptResponse{}
	err := s.db.Pool.QueryRow(ctx,
		`SELECT qa.id, qa.quiz_id, qa.student_id, CONCAT(u.first_name,' ',u.last_name),
		        qa.answers, qa.score, qa.max_score, qa.is_graded, qa.started_at, qa.completed_at
		 FROM quiz_attempts qa
		 JOIN users u ON u.id = qa.student_id
		 WHERE qa.id = $1`, id,
	).Scan(
		&a.ID, &a.QuizID, &a.StudentID, &a.StudentName,
		&a.Answers, &a.Score, &a.MaxScore, &a.IsGraded,
		&a.StartedAt, &a.CompletedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get attempt: %w", err)
	}
	return a, nil
}

// ─── Auto-Grade ─────────────────────────────────────────────────

type question struct {
	Type          string      `json:"type"`
	CorrectAnswer interface{} `json:"correct_answer"`
}

type answer struct {
	QuestionIndex int         `json:"question_index"`
	Answer        interface{} `json:"answer"`
}

func autoGrade(questionsJSON, answersJSON json.RawMessage) (float64, float64) {
	var qs []question
	if err := json.Unmarshal(questionsJSON, &qs); err != nil {
		return 0, float64(len(qs))
	}

	var ans []answer
	if err := json.Unmarshal(answersJSON, &ans); err != nil {
		return 0, float64(len(qs))
	}

	maxScore := float64(len(qs))
	score := float64(0)

	ansMap := make(map[int]interface{})
	for _, a := range ans {
		ansMap[a.QuestionIndex] = a.Answer
	}

	for i, q := range qs {
		// Only auto-grade types with a defined correct_answer
		if q.CorrectAnswer == nil {
			continue
		}
		if studentAns, ok := ansMap[i]; ok {
			if fmt.Sprintf("%v", studentAns) == fmt.Sprintf("%v", q.CorrectAnswer) {
				score++
			}
		}
	}

	return score, maxScore
}
