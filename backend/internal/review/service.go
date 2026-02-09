package review

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
	ErrReviewNotFound  = errors.New("review not found")
	ErrNotAuthorized   = errors.New("not authorized")
	ErrAlreadyReviewed = errors.New("already reviewed this session")
	ErrSessionNotDone  = errors.New("session must be completed before reviewing")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ─── CreateReview ───────────────────────────────────────────────

func (s *Service) CreateReview(ctx context.Context, reviewerID string, req CreateReviewRequest) (*ReviewResponse, error) {
	uid, _ := uuid.Parse(reviewerID)

	// Verify session is completed
	var sessionStatus string
	err := s.db.Pool.QueryRow(ctx,
		`SELECT status FROM sessions WHERE id = $1`, req.SessionID,
	).Scan(&sessionStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("session not found")
		}
		return nil, fmt.Errorf("query session: %w", err)
	}
	if sessionStatus != "completed" {
		return nil, ErrSessionNotDone
	}

	// Check reviewer participated in the session (as student / participant)
	var count int
	err = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_participants WHERE session_id = $1 AND student_id = $2`,
		req.SessionID, uid,
	).Scan(&count)
	if err != nil {
		return nil, fmt.Errorf("check participation: %w", err)
	}
	if count == 0 {
		return nil, ErrNotAuthorized
	}

	var r ReviewResponse
	err = s.db.Pool.QueryRow(ctx,
		`INSERT INTO reviews (session_id, reviewer_id, teacher_id, overall_rating,
		    teaching_quality, communication, punctuality, content_quality, review_text)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		 RETURNING id, session_id, reviewer_id, teacher_id, overall_rating,
		    teaching_quality, communication, punctuality, content_quality,
		    review_text, teacher_response, teacher_responded_at, created_at`,
		req.SessionID, uid, req.TeacherID, req.OverallRating,
		req.TeachingQuality, req.Communication, req.Punctuality, req.ContentQuality, req.ReviewText,
	).Scan(
		&r.ID, &r.SessionID, &r.ReviewerID, &r.TeacherID, &r.OverallRating,
		&r.TeachingQuality, &r.Communication, &r.Punctuality, &r.ContentQuality,
		&r.ReviewText, &r.TeacherResponse, &r.TeacherRespondedAt, &r.CreatedAt,
	)
	if err != nil {
		if isDuplicateKey(err) {
			return nil, ErrAlreadyReviewed
		}
		return nil, fmt.Errorf("insert review: %w", err)
	}

	// Populate names
	s.populateNames(ctx, &r)

	return &r, nil
}

// ─── GetTeacherReviews ──────────────────────────────────────────

func (s *Service) GetTeacherReviews(ctx context.Context, teacherID string, limit, offset int) (*TeacherReviewsResponse, error) {
	tid, _ := uuid.Parse(teacherID)

	// Summary
	var summary TeacherReviewSummary
	err := s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*),
		    COALESCE(AVG(overall_rating), 0),
		    COALESCE(AVG(teaching_quality), 0),
		    COALESCE(AVG(communication), 0),
		    COALESCE(AVG(punctuality), 0),
		    COALESCE(AVG(content_quality), 0)
		 FROM reviews WHERE teacher_id = $1`, tid,
	).Scan(
		&summary.TotalReviews, &summary.AverageRating,
		&summary.AverageTeaching, &summary.AverageComm,
		&summary.AveragePunct, &summary.AverageContent,
	)
	if err != nil {
		return nil, fmt.Errorf("query summary: %w", err)
	}

	// Reviews list
	rows, err := s.db.Pool.Query(ctx,
		`SELECT r.id, r.session_id, r.reviewer_id, r.teacher_id, r.overall_rating,
		    r.teaching_quality, r.communication, r.punctuality, r.content_quality,
		    r.review_text, r.teacher_response, r.teacher_responded_at, r.created_at,
		    u.first_name || ' ' || u.last_name AS reviewer_name,
		    t.first_name || ' ' || t.last_name AS teacher_name
		 FROM reviews r
		 JOIN users u ON u.id = r.reviewer_id
		 JOIN users t ON t.id = r.teacher_id
		 WHERE r.teacher_id = $1
		 ORDER BY r.created_at DESC
		 LIMIT $2 OFFSET $3`, tid, limit, offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query reviews: %w", err)
	}
	defer rows.Close()

	var reviews []ReviewResponse
	for rows.Next() {
		var r ReviewResponse
		if err := rows.Scan(
			&r.ID, &r.SessionID, &r.ReviewerID, &r.TeacherID, &r.OverallRating,
			&r.TeachingQuality, &r.Communication, &r.Punctuality, &r.ContentQuality,
			&r.ReviewText, &r.TeacherResponse, &r.TeacherRespondedAt, &r.CreatedAt,
			&r.ReviewerName, &r.TeacherName,
		); err != nil {
			return nil, fmt.Errorf("scan review: %w", err)
		}
		reviews = append(reviews, r)
	}

	if reviews == nil {
		reviews = []ReviewResponse{}
	}

	return &TeacherReviewsResponse{Summary: summary, Reviews: reviews}, nil
}

// ─── RespondToReview ────────────────────────────────────────────

func (s *Service) RespondToReview(ctx context.Context, teacherID string, reviewID string, response string) (*ReviewResponse, error) {
	rid, _ := uuid.Parse(reviewID)

	// Verify teacher owns this review (is the reviewed teacher)
	var dbTeacherID uuid.UUID
	err := s.db.Pool.QueryRow(ctx,
		`SELECT teacher_id FROM reviews WHERE id = $1`, rid,
	).Scan(&dbTeacherID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrReviewNotFound
		}
		return nil, fmt.Errorf("query review: %w", err)
	}

	if dbTeacherID.String() != teacherID {
		return nil, ErrNotAuthorized
	}

	var r ReviewResponse
	now := time.Now()
	err = s.db.Pool.QueryRow(ctx,
		`UPDATE reviews SET teacher_response = $1, teacher_responded_at = $2
		 WHERE id = $3
		 RETURNING id, session_id, reviewer_id, teacher_id, overall_rating,
		    teaching_quality, communication, punctuality, content_quality,
		    review_text, teacher_response, teacher_responded_at, created_at`,
		response, now, rid,
	).Scan(
		&r.ID, &r.SessionID, &r.ReviewerID, &r.TeacherID, &r.OverallRating,
		&r.TeachingQuality, &r.Communication, &r.Punctuality, &r.ContentQuality,
		&r.ReviewText, &r.TeacherResponse, &r.TeacherRespondedAt, &r.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update review: %w", err)
	}

	s.populateNames(ctx, &r)
	return &r, nil
}

// ─── Helpers ────────────────────────────────────────────────────

func (s *Service) populateNames(ctx context.Context, r *ReviewResponse) {
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, r.ReviewerID,
	).Scan(&r.ReviewerName)
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT first_name || ' ' || last_name FROM users WHERE id = $1`, r.TeacherID,
	).Scan(&r.TeacherName)
}

func isDuplicateKey(err error) bool {
	return err != nil && (contains(err.Error(), "duplicate key") || contains(err.Error(), "unique constraint"))
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
