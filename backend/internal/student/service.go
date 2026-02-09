package student

import (
	"context"
	"errors"
	"fmt"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrProfileNotFound = errors.New("student profile not found")

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

func (s *Service) GetProfile(ctx context.Context, userID string) (*StudentProfileResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrProfileNotFound
	}

	var p StudentProfileResponse
	err = s.db.Pool.QueryRow(ctx,
		`SELECT sp.user_id, u.first_name, u.last_name, COALESCE(u.avatar_url,''),
		        COALESCE(u.email,''), COALESCE(u.phone,''),
		        COALESCE(l.name,''), COALESCE(l.code,''), COALESCE(l.cycle::text,''),
		        COALESCE(sp.filiere,''), COALESCE(sp.school,''), sp.date_of_birth
		 FROM student_profiles sp
		 JOIN users u ON u.id = sp.user_id
		 LEFT JOIN levels l ON l.id = sp.level_id
		 WHERE sp.user_id = $1`, uid,
	).Scan(
		&p.UserID, &p.FirstName, &p.LastName, &p.AvatarURL,
		&p.Email, &p.Phone,
		&p.LevelName, &p.LevelCode, &p.Cycle,
		&p.Filiere, &p.School, &p.DateOfBirth,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrProfileNotFound
		}
		return nil, fmt.Errorf("query student: %w", err)
	}

	return &p, nil
}

func (s *Service) GetDashboard(ctx context.Context, userID string) (*StudentDashboardResponse, error) {
	profile, err := s.GetProfile(ctx, userID)
	if err != nil {
		return nil, err
	}

	uid, _ := uuid.Parse(userID)

	// Upcoming sessions
	rows, err := s.db.Pool.Query(ctx,
		`SELECT s.id, s.title, u.first_name || ' ' || u.last_name, s.start_time, s.end_time, s.status
		 FROM sessions s
		 JOIN session_participants sp ON sp.session_id = s.id
		 JOIN users u ON u.id = s.teacher_id
		 WHERE sp.student_id = $1 AND s.status = 'scheduled' AND s.start_time > NOW()
		 ORDER BY s.start_time ASC LIMIT 5`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("upcoming sessions: %w", err)
	}
	defer rows.Close()

	var upcoming []SessionBrief
	for rows.Next() {
		var sb SessionBrief
		if err := rows.Scan(&sb.ID, &sb.Title, &sb.TeacherName, &sb.StartTime, &sb.EndTime, &sb.Status); err != nil {
			return nil, err
		}
		upcoming = append(upcoming, sb)
	}

	// Counts
	var totalSessions, totalCourses int
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_participants WHERE student_id = $1`, uid,
	).Scan(&totalSessions)

	return &StudentDashboardResponse{
		Profile:          *profile,
		UpcomingSessions: upcoming,
		TotalSessions:    totalSessions,
		TotalCourses:     totalCourses,
	}, nil
}

func (s *Service) GetEnrollments(ctx context.Context, userID string, page, limit int) ([]EnrollmentResponse, int64, error) {
	uid, _ := uuid.Parse(userID)
	offset := (page - 1) * limit

	var total int64
	_ = s.db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM session_participants WHERE student_id = $1`, uid,
	).Scan(&total)

	rows, err := s.db.Pool.Query(ctx,
		`SELECT s.id, s.title, u.first_name || ' ' || u.last_name, s.start_time, s.status, sp.attendance
		 FROM session_participants sp
		 JOIN sessions s ON s.id = sp.session_id
		 JOIN users u ON u.id = s.teacher_id
		 WHERE sp.student_id = $1
		 ORDER BY s.start_time DESC
		 LIMIT $2 OFFSET $3`, uid, limit, offset,
	)
	if err != nil {
		return nil, 0, fmt.Errorf("enrollments: %w", err)
	}
	defer rows.Close()

	var enrollments []EnrollmentResponse
	for rows.Next() {
		var e EnrollmentResponse
		if err := rows.Scan(&e.SessionID, &e.Title, &e.TeacherName, &e.StartTime, &e.Status, &e.Attendance); err != nil {
			return nil, 0, err
		}
		enrollments = append(enrollments, e)
	}

	return enrollments, total, nil
}
