package homework

import (
	"context"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrHomeworkNotFound   = errors.New("homework not found")
	ErrSubmissionNotFound = errors.New("submission not found")
	ErrNotAuthorized      = errors.New("not authorized")
	ErrAlreadySubmitted   = errors.New("already submitted")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ─── Homework CRUD ──────────────────────────────────────────────

func (s *Service) CreateHomework(ctx context.Context, teacherID string, req CreateHomeworkRequest) (*HomeworkResponse, error) {
	tid, _ := uuid.Parse(teacherID)
	id := uuid.New()

	var deadline *time.Time
	if req.Deadline != nil {
		t, err := time.Parse(time.RFC3339, *req.Deadline)
		if err == nil {
			deadline = &t
		}
	}

	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO homework (id, teacher_id, title, description, instructions, subject_id, level_id, deadline, allow_late, late_penalty_percent)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		id, tid, req.Title, req.Description, req.Instructions,
		req.SubjectID, req.LevelID, deadline, req.AllowLate, req.LatePenaltyPercent,
	)
	if err != nil {
		return nil, fmt.Errorf("create homework: %w", err)
	}

	// Assign to students if provided
	for _, sid := range req.StudentIDs {
		studentID, _ := uuid.Parse(sid)
		_, _ = s.db.Pool.Exec(ctx,
			`INSERT INTO homework_assignments (id, homework_id, student_id) VALUES ($1,$2,$3)
			 ON CONFLICT (homework_id, student_id) DO NOTHING`,
			uuid.New(), id, studentID)
	}

	return s.GetHomework(ctx, id.String())
}

func (s *Service) GetHomework(ctx context.Context, homeworkID string) (*HomeworkResponse, error) {
	hid, _ := uuid.Parse(homeworkID)
	h := &HomeworkResponse{}

	var subjectID, levelID *uuid.UUID
	var subjectName, levelName *string

	err := s.db.Pool.QueryRow(ctx,
		`SELECT hw.id, hw.teacher_id, CONCAT(u.first_name,' ',u.last_name),
		        hw.title, COALESCE(hw.description,''), COALESCE(hw.instructions,''),
		        hw.file_urls, hw.subject_id, hw.level_id,
		        s.name_fr, l.name,
		        hw.deadline, hw.allow_late, hw.late_penalty_percent,
		        hw.created_at, hw.updated_at
		 FROM homework hw
		 JOIN users u ON u.id = hw.teacher_id
		 LEFT JOIN subjects s ON s.id = hw.subject_id
		 LEFT JOIN levels l ON l.id = hw.level_id
		 WHERE hw.id = $1`, hid,
	).Scan(
		&h.ID, &h.TeacherID, &h.TeacherName,
		&h.Title, &h.Description, &h.Instructions,
		&h.FileURLs, &subjectID, &levelID,
		&subjectName, &levelName,
		&h.Deadline, &h.AllowLate, &h.LatePenaltyPercent,
		&h.CreatedAt, &h.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHomeworkNotFound
		}
		return nil, fmt.Errorf("get homework: %w", err)
	}

	h.SubjectID = subjectID
	h.LevelID = levelID
	if subjectName != nil {
		h.SubjectName = *subjectName
	}
	if levelName != nil {
		h.LevelName = *levelName
	}
	if h.FileURLs == nil {
		h.FileURLs = []string{}
	}

	return h, nil
}

func (s *Service) ListHomework(ctx context.Context, userID, role string, page, limit int) ([]HomeworkResponse, int64, error) {
	offset := (page - 1) * limit
	uid, _ := uuid.Parse(userID)

	var total int64
	var filterSQL string
	args := []interface{}{limit, offset}

	if role == "teacher" {
		filterSQL = "WHERE hw.teacher_id = $3"
		args = append(args, uid)
	} else {
		// Students see homework assigned to them
		filterSQL = "WHERE hw.id IN (SELECT homework_id FROM homework_assignments WHERE student_id = $3)"
		args = append(args, uid)
	}

	countQ := fmt.Sprintf(`SELECT COUNT(*) FROM homework hw %s`, filterSQL)
	_ = s.db.Pool.QueryRow(ctx, countQ, args[2:]...).Scan(&total)

	q := fmt.Sprintf(
		`SELECT hw.id, hw.teacher_id, CONCAT(u.first_name,' ',u.last_name),
		        hw.title, COALESCE(hw.description,''), COALESCE(hw.instructions,''),
		        hw.file_urls, hw.subject_id, hw.level_id,
		        s.name_fr, l.name,
		        hw.deadline, hw.allow_late, hw.late_penalty_percent,
		        hw.created_at, hw.updated_at
		 FROM homework hw
		 JOIN users u ON u.id = hw.teacher_id
		 LEFT JOIN subjects s ON s.id = hw.subject_id
		 LEFT JOIN levels l ON l.id = hw.level_id
		 %s
		 ORDER BY hw.created_at DESC LIMIT $1 OFFSET $2`, filterSQL)

	rows, err := s.db.Pool.Query(ctx, q, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list homework: %w", err)
	}
	defer rows.Close()

	var list []HomeworkResponse
	for rows.Next() {
		var h HomeworkResponse
		var subjectID, levelID *uuid.UUID
		var subjectName, levelName *string
		if err := rows.Scan(
			&h.ID, &h.TeacherID, &h.TeacherName,
			&h.Title, &h.Description, &h.Instructions,
			&h.FileURLs, &subjectID, &levelID,
			&subjectName, &levelName,
			&h.Deadline, &h.AllowLate, &h.LatePenaltyPercent,
			&h.CreatedAt, &h.UpdatedAt,
		); err != nil {
			continue
		}
		h.SubjectID = subjectID
		h.LevelID = levelID
		if subjectName != nil {
			h.SubjectName = *subjectName
		}
		if levelName != nil {
			h.LevelName = *levelName
		}
		if h.FileURLs == nil {
			h.FileURLs = []string{}
		}
		list = append(list, h)
	}
	if list == nil {
		list = []HomeworkResponse{}
	}
	return list, total, nil
}

// ─── Submit ─────────────────────────────────────────────────────

func (s *Service) SubmitHomework(ctx context.Context, homeworkID, studentID string, req SubmitHomeworkRequest) (*SubmissionResponse, error) {
	hid, _ := uuid.Parse(homeworkID)
	sid, _ := uuid.Parse(studentID)

	// Check homework exists
	var deadline *time.Time
	err := s.db.Pool.QueryRow(ctx, `SELECT deadline FROM homework WHERE id = $1`, hid).Scan(&deadline)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHomeworkNotFound
		}
		return nil, err
	}

	isLate := false
	if deadline != nil && time.Now().After(*deadline) {
		isLate = true
	}

	id := uuid.New()
	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO homework_submissions (id, homework_id, student_id, text_content, file_urls, is_late, submitted_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		id, hid, sid, req.TextContent, req.FileURLs, isLate, now,
	)
	if err != nil {
		return nil, fmt.Errorf("submit homework: %w", err)
	}

	// Update assignment status
	_, _ = s.db.Pool.Exec(ctx,
		`UPDATE homework_assignments SET status = 'submitted' WHERE homework_id = $1 AND student_id = $2`, hid, sid)

	return s.getSubmission(ctx, id)
}

// ─── Grade ──────────────────────────────────────────────────────

func (s *Service) GradeHomework(ctx context.Context, submissionID, teacherID string, req GradeHomeworkRequest) (*SubmissionResponse, error) {
	subID, _ := uuid.Parse(submissionID)
	tid, _ := uuid.Parse(teacherID)

	// Verify teacher owns the homework
	var hwTeacherID uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT hw.teacher_id FROM homework_submissions hs
		 JOIN homework hw ON hw.id = hs.homework_id
		 WHERE hs.id = $1`, subID,
	).Scan(&hwTeacherID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSubmissionNotFound
		}
		return nil, err
	}
	if hwTeacherID != tid {
		return nil, ErrNotAuthorized
	}

	now := time.Now()
	_, err = s.db.Pool.Exec(ctx,
		`UPDATE homework_submissions SET grade = $1, max_grade = $2, feedback = $3, graded_at = $4 WHERE id = $5`,
		req.Grade, req.MaxGrade, req.Feedback, now, subID,
	)
	if err != nil {
		return nil, fmt.Errorf("grade homework: %w", err)
	}

	// Update assignment status
	_, _ = s.db.Pool.Exec(ctx,
		`UPDATE homework_assignments ha
		 SET status = 'graded'
		 FROM homework_submissions hs
		 WHERE hs.id = $1 AND ha.homework_id = hs.homework_id AND ha.student_id = hs.student_id`, subID)

	return s.getSubmission(ctx, subID)
}

func (s *Service) getSubmission(ctx context.Context, id uuid.UUID) (*SubmissionResponse, error) {
	sub := &SubmissionResponse{}
	err := s.db.Pool.QueryRow(ctx,
		`SELECT hs.id, hs.homework_id, hs.student_id, CONCAT(u.first_name,' ',u.last_name),
		        hs.file_urls, COALESCE(hs.text_content,''), hs.grade, hs.max_grade,
		        COALESCE(hs.feedback,''), hs.is_late, hs.submitted_at, hs.graded_at
		 FROM homework_submissions hs
		 JOIN users u ON u.id = hs.student_id
		 WHERE hs.id = $1`, id,
	).Scan(
		&sub.ID, &sub.HomeworkID, &sub.StudentID, &sub.StudentName,
		&sub.FileURLs, &sub.TextContent, &sub.Grade, &sub.MaxGrade,
		&sub.Feedback, &sub.IsLate, &sub.SubmittedAt, &sub.GradedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get submission: %w", err)
	}
	if sub.FileURLs == nil {
		sub.FileURLs = []string{}
	}
	return sub, nil
}
