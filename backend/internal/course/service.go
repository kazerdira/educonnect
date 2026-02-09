package course

import (
	"context"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/database"
	"educonnect/pkg/storage"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrCourseNotFound  = errors.New("course not found")
	ErrChapterNotFound = errors.New("chapter not found")
	ErrLessonNotFound  = errors.New("lesson not found")
	ErrNotAuthorized   = errors.New("not authorized")
	ErrAlreadyEnrolled = errors.New("already enrolled")
)

type Service struct {
	db      *database.Postgres
	storage *storage.MinIO
}

func NewService(db *database.Postgres, st *storage.MinIO) *Service {
	return &Service{db: db, storage: st}
}

// ─── Course CRUD ────────────────────────────────────────────────

func (s *Service) CreateCourse(ctx context.Context, teacherID string, req CreateCourseRequest) (*CourseResponse, error) {
	tid, _ := uuid.Parse(teacherID)
	id := uuid.New()

	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO courses (id, teacher_id, title, description, subject_id, level_id, price, is_published)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		id, tid, req.Title, req.Description, req.SubjectID, req.LevelID, req.Price, req.IsPublished,
	)
	if err != nil {
		return nil, fmt.Errorf("create course: %w", err)
	}
	return s.GetCourse(ctx, id.String())
}

func (s *Service) GetCourse(ctx context.Context, courseID string) (*CourseResponse, error) {
	cid, _ := uuid.Parse(courseID)
	c := &CourseResponse{}

	var subjectID, levelID *uuid.UUID
	var subjectName, levelName *string

	err := s.db.Pool.QueryRow(ctx,
		`SELECT c.id, c.teacher_id,
		        CONCAT(u.first_name,' ',u.last_name),
		        c.title, COALESCE(c.description,''), c.subject_id, c.level_id,
		        s.name_fr, l.name,
		        c.price, c.is_published, COALESCE(c.thumbnail_url,''),
		        c.enrollment_count, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.teacher_id
		 LEFT JOIN subjects s ON s.id = c.subject_id
		 LEFT JOIN levels l ON l.id = c.level_id
		 WHERE c.id = $1`, cid,
	).Scan(
		&c.ID, &c.TeacherID, &c.TeacherName,
		&c.Title, &c.Description, &subjectID, &levelID,
		&subjectName, &levelName,
		&c.Price, &c.IsPublished, &c.ThumbnailURL,
		&c.EnrollmentCount, &c.CreatedAt, &c.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCourseNotFound
		}
		return nil, fmt.Errorf("get course: %w", err)
	}

	c.SubjectID = subjectID
	c.LevelID = levelID
	if subjectName != nil {
		c.SubjectName = *subjectName
	}
	if levelName != nil {
		c.LevelName = *levelName
	}

	// Fetch chapters + lessons
	chapters, err := s.listChapters(ctx, cid)
	if err == nil {
		c.Chapters = chapters
	}

	return c, nil
}

func (s *Service) ListCourses(ctx context.Context, teacherID string, page, limit int) ([]CourseResponse, int64, error) {
	offset := (page - 1) * limit

	var total int64
	filterSQL := ""
	args := []interface{}{limit, offset}

	if teacherID != "" {
		filterSQL = "WHERE c.teacher_id = $3"
		tid, _ := uuid.Parse(teacherID)
		args = append(args, tid)
	}

	countQ := fmt.Sprintf(`SELECT COUNT(*) FROM courses c %s`, filterSQL)
	_ = s.db.Pool.QueryRow(ctx, countQ, args[2:]...).Scan(&total)

	q := fmt.Sprintf(
		`SELECT c.id, c.teacher_id, CONCAT(u.first_name,' ',u.last_name),
		        c.title, COALESCE(c.description,''), c.subject_id, c.level_id,
		        s.name_fr, l.name,
		        c.price, c.is_published, COALESCE(c.thumbnail_url,''),
		        c.enrollment_count, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.teacher_id
		 LEFT JOIN subjects s ON s.id = c.subject_id
		 LEFT JOIN levels l ON l.id = c.level_id
		 %s
		 ORDER BY c.created_at DESC
		 LIMIT $1 OFFSET $2`, filterSQL)

	rows, err := s.db.Pool.Query(ctx, q, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list courses: %w", err)
	}
	defer rows.Close()

	var courses []CourseResponse
	for rows.Next() {
		var r CourseResponse
		var subjectID, levelID *uuid.UUID
		var subjectName, levelName *string
		if err := rows.Scan(
			&r.ID, &r.TeacherID, &r.TeacherName,
			&r.Title, &r.Description, &subjectID, &levelID,
			&subjectName, &levelName,
			&r.Price, &r.IsPublished, &r.ThumbnailURL,
			&r.EnrollmentCount, &r.CreatedAt, &r.UpdatedAt,
		); err != nil {
			continue
		}
		r.SubjectID = subjectID
		r.LevelID = levelID
		if subjectName != nil {
			r.SubjectName = *subjectName
		}
		if levelName != nil {
			r.LevelName = *levelName
		}
		courses = append(courses, r)
	}
	if courses == nil {
		courses = []CourseResponse{}
	}
	return courses, total, nil
}

func (s *Service) UpdateCourse(ctx context.Context, courseID, teacherID string, req UpdateCourseRequest) (*CourseResponse, error) {
	cid, _ := uuid.Parse(courseID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership
	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT teacher_id FROM courses WHERE id = $1`, cid).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCourseNotFound
		}
		return nil, err
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	// Build dynamic update
	sets := []string{}
	args := []interface{}{}
	idx := 1

	if req.Title != nil {
		sets = append(sets, fmt.Sprintf("title = $%d", idx))
		args = append(args, *req.Title)
		idx++
	}
	if req.Description != nil {
		sets = append(sets, fmt.Sprintf("description = $%d", idx))
		args = append(args, *req.Description)
		idx++
	}
	if req.SubjectID != nil {
		sets = append(sets, fmt.Sprintf("subject_id = $%d", idx))
		args = append(args, *req.SubjectID)
		idx++
	}
	if req.LevelID != nil {
		sets = append(sets, fmt.Sprintf("level_id = $%d", idx))
		args = append(args, *req.LevelID)
		idx++
	}
	if req.Price != nil {
		sets = append(sets, fmt.Sprintf("price = $%d", idx))
		args = append(args, *req.Price)
		idx++
	}
	if req.IsPublished != nil {
		sets = append(sets, fmt.Sprintf("is_published = $%d", idx))
		args = append(args, *req.IsPublished)
		idx++
	}
	if req.ThumbnailURL != nil {
		sets = append(sets, fmt.Sprintf("thumbnail_url = $%d", idx))
		args = append(args, *req.ThumbnailURL)
		idx++
	}

	if len(sets) == 0 {
		return s.GetCourse(ctx, courseID)
	}

	sets = append(sets, fmt.Sprintf("updated_at = $%d", idx))
	args = append(args, time.Now())
	idx++

	args = append(args, cid)
	q := fmt.Sprintf(`UPDATE courses SET %s WHERE id = $%d`, joinStrings(sets, ", "), idx)
	_, err = s.db.Pool.Exec(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("update course: %w", err)
	}
	return s.GetCourse(ctx, courseID)
}

func (s *Service) DeleteCourse(ctx context.Context, courseID, teacherID string) error {
	cid, _ := uuid.Parse(courseID)
	tid, _ := uuid.Parse(teacherID)

	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT teacher_id FROM courses WHERE id = $1`, cid).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrCourseNotFound
		}
		return err
	}
	if ownerID != tid {
		return ErrNotAuthorized
	}

	_, err = s.db.Pool.Exec(ctx, `DELETE FROM courses WHERE id = $1`, cid)
	return err
}

// ─── Chapters ───────────────────────────────────────────────────

func (s *Service) CreateChapter(ctx context.Context, courseID, teacherID string, req CreateChapterRequest) (*ChapterResponse, error) {
	cid, _ := uuid.Parse(courseID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership
	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT teacher_id FROM courses WHERE id = $1`, cid).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCourseNotFound
		}
		return nil, err
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	id := uuid.New()
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO chapters (id, course_id, title, "order") VALUES ($1,$2,$3,$4)`,
		id, cid, req.Title, req.Order,
	)
	if err != nil {
		return nil, fmt.Errorf("create chapter: %w", err)
	}

	ch := &ChapterResponse{ID: id, CourseID: cid, Title: req.Title, Order: req.Order, CreatedAt: time.Now()}
	return ch, nil
}

func (s *Service) listChapters(ctx context.Context, courseID uuid.UUID) ([]ChapterResponse, error) {
	rows, err := s.db.Pool.Query(ctx,
		`SELECT id, course_id, title, "order", created_at FROM chapters WHERE course_id = $1 ORDER BY "order"`, courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var chapters []ChapterResponse
	for rows.Next() {
		var ch ChapterResponse
		if err := rows.Scan(&ch.ID, &ch.CourseID, &ch.Title, &ch.Order, &ch.CreatedAt); err != nil {
			continue
		}
		lessons, _ := s.listLessons(ctx, ch.ID)
		ch.Lessons = lessons
		chapters = append(chapters, ch)
	}
	if chapters == nil {
		chapters = []ChapterResponse{}
	}
	return chapters, nil
}

// ─── Lessons ────────────────────────────────────────────────────

func (s *Service) CreateLesson(ctx context.Context, courseID, chapterID, teacherID string, req CreateLessonRequest) (*LessonResponse, error) {
	cid, _ := uuid.Parse(courseID)
	chid, _ := uuid.Parse(chapterID)
	tid, _ := uuid.Parse(teacherID)

	// Verify ownership
	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT teacher_id FROM courses WHERE id = $1`, cid).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCourseNotFound
		}
		return nil, err
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	// Verify chapter belongs to course
	var chCourseID uuid.UUID
	err = s.db.Pool.QueryRow(ctx, `SELECT course_id FROM chapters WHERE id = $1`, chid).Scan(&chCourseID)
	if err != nil {
		return nil, ErrChapterNotFound
	}
	if chCourseID != cid {
		return nil, ErrChapterNotFound
	}

	id := uuid.New()
	_, err = s.db.Pool.Exec(ctx,
		`INSERT INTO lessons (id, chapter_id, title, description, "order", is_preview) VALUES ($1,$2,$3,$4,$5,$6)`,
		id, chid, req.Title, req.Description, req.Order, req.IsPreview,
	)
	if err != nil {
		return nil, fmt.Errorf("create lesson: %w", err)
	}

	return &LessonResponse{
		ID: id, ChapterID: chid, Title: req.Title, Description: req.Description,
		Order: req.Order, IsPreview: req.IsPreview, CreatedAt: time.Now(),
	}, nil
}

func (s *Service) listLessons(ctx context.Context, chapterID uuid.UUID) ([]LessonResponse, error) {
	rows, err := s.db.Pool.Query(ctx,
		`SELECT id, chapter_id, title, COALESCE(description,''), COALESCE(video_url,''), duration, "order", is_preview, created_at
		 FROM lessons WHERE chapter_id = $1 ORDER BY "order"`, chapterID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lessons []LessonResponse
	for rows.Next() {
		var l LessonResponse
		if err := rows.Scan(&l.ID, &l.ChapterID, &l.Title, &l.Description, &l.VideoURL, &l.Duration, &l.Order, &l.IsPreview, &l.CreatedAt); err != nil {
			continue
		}
		lessons = append(lessons, l)
	}
	if lessons == nil {
		lessons = []LessonResponse{}
	}
	return lessons, nil
}

// ─── Video Upload ───────────────────────────────────────────────

func (s *Service) UploadVideo(ctx context.Context, courseID, lessonID, teacherID string, reader interface{ Read([]byte) (int, error) }, size int64, contentType string) (*UploadVideoResponse, error) {
	cid, _ := uuid.Parse(courseID)
	lid, _ := uuid.Parse(lessonID)
	tid, _ := uuid.Parse(teacherID)

	// Verify course ownership
	var ownerID uuid.UUID
	err := s.db.Pool.QueryRow(ctx, `SELECT teacher_id FROM courses WHERE id = $1`, cid).Scan(&ownerID)
	if err != nil {
		return nil, ErrCourseNotFound
	}
	if ownerID != tid {
		return nil, ErrNotAuthorized
	}

	// Verify lesson belongs to course
	var count int
	err = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM lessons le
		 JOIN chapters ch ON ch.id = le.chapter_id
		 WHERE le.id = $1 AND ch.course_id = $2`, lid, cid).Scan(&count)
	if err != nil || count == 0 {
		return nil, ErrLessonNotFound
	}

	key := fmt.Sprintf("courses/%s/lessons/%s/%d", cid, lid, time.Now().UnixMilli())

	ioReader, ok := reader.(interface {
		Read([]byte) (int, error)
	})
	if !ok {
		return nil, fmt.Errorf("invalid reader")
	}

	bucket := s.storage.BucketVideos()
	if err := s.storage.Upload(ctx, bucket, key, ioReader, size, contentType); err != nil {
		return nil, fmt.Errorf("upload video: %w", err)
	}

	videoURL := fmt.Sprintf("/%s/%s", bucket, key)
	_, err = s.db.Pool.Exec(ctx, `UPDATE lessons SET video_url = $1 WHERE id = $2`, videoURL, lid)
	if err != nil {
		return nil, fmt.Errorf("update lesson video: %w", err)
	}

	return &UploadVideoResponse{VideoURL: videoURL}, nil
}

// ─── Enrollment ─────────────────────────────────────────────────

func (s *Service) EnrollStudent(ctx context.Context, courseID, studentID string) (*EnrollmentResponse, error) {
	cid, _ := uuid.Parse(courseID)
	sid, _ := uuid.Parse(studentID)

	// Check course exists
	var exists bool
	_ = s.db.Pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM courses WHERE id = $1)`, cid).Scan(&exists)
	if !exists {
		return nil, ErrCourseNotFound
	}

	id := uuid.New()
	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO course_enrollments (id, course_id, student_id) VALUES ($1,$2,$3)
		 ON CONFLICT (course_id, student_id) DO NOTHING`, id, cid, sid)
	if err != nil {
		return nil, fmt.Errorf("enroll: %w", err)
	}

	// Update enrollment count
	_, _ = s.db.Pool.Exec(ctx,
		`UPDATE courses SET enrollment_count = (SELECT COUNT(*) FROM course_enrollments WHERE course_id = $1) WHERE id = $1`, cid)

	var e EnrollmentResponse
	err = s.db.Pool.QueryRow(ctx,
		`SELECT ce.id, ce.course_id, c.title, ce.student_id, ce.progress_percent, ce.last_lesson_id, ce.enrolled_at
		 FROM course_enrollments ce JOIN courses c ON c.id = ce.course_id
		 WHERE ce.course_id = $1 AND ce.student_id = $2`, cid, sid,
	).Scan(&e.ID, &e.CourseID, &e.CourseTitle, &e.StudentID, &e.ProgressPercent, &e.LastLessonID, &e.EnrolledAt)
	if err != nil {
		return nil, fmt.Errorf("fetch enrollment: %w", err)
	}
	return &e, nil
}

// ─── Helpers ────────────────────────────────────────────────────

func joinStrings(ss []string, sep string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += sep
		}
		result += s
	}
	return result
}
