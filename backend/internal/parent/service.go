package parent

import (
	"context"
	"errors"
	"fmt"
	"time"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrProfileNotFound = errors.New("parent profile not found")
	ErrChildNotFound   = errors.New("child not found")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// ListChildren returns all children linked to the parent.
func (s *Service) ListChildren(ctx context.Context, parentID string) ([]ChildResponse, error) {
	uid, err := uuid.Parse(parentID)
	if err != nil {
		return nil, ErrProfileNotFound
	}

	rows, err := s.db.Pool.Query(ctx,
		`SELECT u.id, u.first_name, u.last_name, COALESCE(u.avatar_url,''),
		        COALESCE(l.name,''), COALESCE(l.code,''), COALESCE(l.cycle::text,''),
		        COALESCE(sp.filiere,''), COALESCE(sp.school,''), sp.date_of_birth
		 FROM student_profiles sp
		 JOIN users u ON u.id = sp.user_id
		 LEFT JOIN levels l ON l.id = sp.level_id
		 WHERE sp.parent_id = $1
		 ORDER BY u.first_name`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("list children: %w", err)
	}
	defer rows.Close()

	var children []ChildResponse
	for rows.Next() {
		var ch ChildResponse
		if err := rows.Scan(
			&ch.ID, &ch.FirstName, &ch.LastName, &ch.AvatarURL,
			&ch.LevelName, &ch.LevelCode, &ch.Cycle,
			&ch.Filiere, &ch.School, &ch.DateOfBirth,
		); err != nil {
			return nil, err
		}
		children = append(children, ch)
	}
	return children, nil
}

// AddChild creates a student user + profile, then links to the parent.
func (s *Service) AddChild(ctx context.Context, parentID string, req AddChildRequest) (*ChildResponse, error) {
	parentUID, err := uuid.Parse(parentID)
	if err != nil {
		return nil, ErrProfileNotFound
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	childID := uuid.New()

	// Create user with role student (managed by parent — random password)
	tempHash, _ := bcrypt.GenerateFromPassword([]byte(uuid.New().String()), 10)
	_, err = tx.Exec(ctx,
		`INSERT INTO users (id, first_name, last_name, role, password_hash, is_active)
		 VALUES ($1, $2, $3, 'student', $4, true)`,
		childID, req.FirstName, req.LastName, string(tempHash),
	)
	if err != nil {
		return nil, fmt.Errorf("create child user: %w", err)
	}

	// Find level_id from code or UUID
	var levelID *uuid.UUID
	if req.LevelCode != "" {
		// First try parsing as UUID
		if parsed, parseErr := uuid.Parse(req.LevelCode); parseErr == nil {
			levelID = &parsed
		} else {
			// Otherwise look up by code
			var lid uuid.UUID
			err = tx.QueryRow(ctx, `SELECT id FROM levels WHERE code = $1`, req.LevelCode).Scan(&lid)
			if err == nil {
				levelID = &lid
			}
		}
	}

	var dob *time.Time
	if req.DateOfBirth != "" {
		t, e := time.Parse("2006-01-02", req.DateOfBirth)
		if e == nil {
			dob = &t
		}
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO student_profiles (user_id, level_id, filiere, school, date_of_birth, parent_id, is_independent)
		 VALUES ($1, $2, $3, $4, $5, $6, false)`,
		childID, levelID, req.Filiere, req.School, dob, parentUID,
	)
	if err != nil {
		return nil, fmt.Errorf("create student profile: %w", err)
	}

	if err = tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return &ChildResponse{
		ID:        childID.String(),
		FirstName: req.FirstName,
		LastName:  req.LastName,
		LevelCode: req.LevelCode,
		Filiere:   req.Filiere,
		School:    req.School,
	}, nil
}

// UpdateChild updates the child's basic info and student profile.
func (s *Service) UpdateChild(ctx context.Context, parentID, childID string, req UpdateChildRequest) (*ChildResponse, error) {
	if !s.isChildOfParent(ctx, parentID, childID) {
		return nil, ErrChildNotFound
	}

	cuid, _ := uuid.Parse(childID)

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Update user name fields if provided
	if req.FirstName != nil {
		_, _ = tx.Exec(ctx, `UPDATE users SET first_name = $1 WHERE id = $2`, *req.FirstName, cuid)
	}
	if req.LastName != nil {
		_, _ = tx.Exec(ctx, `UPDATE users SET last_name = $1 WHERE id = $2`, *req.LastName, cuid)
	}

	// Update student profile fields if provided
	if req.LevelCode != nil {
		var levelID *uuid.UUID
		// First try parsing as UUID
		if parsed, parseErr := uuid.Parse(*req.LevelCode); parseErr == nil {
			levelID = &parsed
		} else {
			// Otherwise look up by code
			var lid uuid.UUID
			if errL := tx.QueryRow(ctx, `SELECT id FROM levels WHERE code = $1`, *req.LevelCode).Scan(&lid); errL == nil {
				levelID = &lid
			}
		}
		_, _ = tx.Exec(ctx, `UPDATE student_profiles SET level_id = $1 WHERE user_id = $2`, levelID, cuid)
	}
	if req.School != nil {
		_, _ = tx.Exec(ctx, `UPDATE student_profiles SET school = $1 WHERE user_id = $2`, *req.School, cuid)
	}

	if err = tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	// Re-fetch updated profile
	var ch ChildResponse
	err = s.db.Pool.QueryRow(ctx,
		`SELECT u.id, u.first_name, u.last_name, COALESCE(u.avatar_url,''),
		        COALESCE(l.name,''), COALESCE(l.code,''), COALESCE(l.cycle::text,''),
		        COALESCE(sp.filiere,''), COALESCE(sp.school,''), sp.date_of_birth
		 FROM users u
		 JOIN student_profiles sp ON sp.user_id = u.id
		 LEFT JOIN levels l ON l.id = sp.level_id
		 WHERE u.id = $1`, cuid,
	).Scan(
		&ch.ID, &ch.FirstName, &ch.LastName, &ch.AvatarURL,
		&ch.LevelName, &ch.LevelCode, &ch.Cycle,
		&ch.Filiere, &ch.School, &ch.DateOfBirth,
	)
	if err != nil {
		return nil, ErrChildNotFound
	}
	return &ch, nil
}

// RemoveChild unlinks a child from the parent (does NOT delete the user).
func (s *Service) RemoveChild(ctx context.Context, parentID, childID string) error {
	puid, _ := uuid.Parse(parentID)
	cuid, _ := uuid.Parse(childID)

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE student_profiles SET parent_id = NULL WHERE parent_id = $1 AND user_id = $2`, puid, cuid,
	)
	if err != nil {
		return fmt.Errorf("remove child: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrChildNotFound
	}
	return nil
}

// GetChildProgress returns the child's recent sessions & counts.
func (s *Service) GetChildProgress(ctx context.Context, parentID, childID string) (map[string]interface{}, error) {
	if !s.isChildOfParent(ctx, parentID, childID) {
		return nil, ErrChildNotFound
	}

	cuid, _ := uuid.Parse(childID)

	var total int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_participants WHERE student_id = $1`, cuid,
	).Scan(&total)

	var completed int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_participants sp
		 JOIN sessions s ON s.id = sp.session_id
		 WHERE sp.student_id = $1 AND s.status = 'completed'`, cuid,
	).Scan(&completed)

	return map[string]interface{}{
		"child_id":           childID,
		"total_sessions":     total,
		"completed_sessions": completed,
	}, nil
}

// GetDashboard returns parent overview: children list + summary stats.
func (s *Service) GetDashboard(ctx context.Context, parentID string) (*ParentDashboardResponse, error) {
	children, err := s.ListChildren(ctx, parentID)
	if err != nil {
		return nil, err
	}

	var totalSessions int
	for _, ch := range children {
		cuid, _ := uuid.Parse(ch.ID)
		var cnt int
		_ = s.db.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM session_participants WHERE student_id = $1`, cuid,
		).Scan(&cnt)
		totalSessions += cnt
	}

	var upcomingSessions int
	uid, _ := uuid.Parse(parentID)
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*)
		 FROM sessions s
		 JOIN session_participants sp ON sp.session_id = s.id
		 JOIN student_profiles stup ON stup.user_id = sp.student_id
		 WHERE stup.parent_id = $1 AND s.status = 'scheduled' AND s.start_time > NOW()`, uid,
	).Scan(&upcomingSessions)

	return &ParentDashboardResponse{
		Children:         children,
		TotalChildren:    len(children),
		TotalSessions:    totalSessions,
		UpcomingSessions: upcomingSessions,
	}, nil
}

func (s *Service) isChildOfParent(ctx context.Context, parentID, childID string) bool {
	puid, _ := uuid.Parse(parentID)
	cuid, _ := uuid.Parse(childID)
	var exists bool
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM student_profiles WHERE parent_id=$1 AND user_id=$2)`,
		puid, cuid,
	).Scan(&exists)
	return exists
}
