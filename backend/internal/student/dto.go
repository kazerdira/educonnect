package student

import (
	"time"

	"github.com/google/uuid"
)

// ─── Responses ──────────────────────────────────────────────────

type StudentProfileResponse struct {
	UserID      uuid.UUID  `json:"user_id"`
	FirstName   string     `json:"first_name"`
	LastName    string     `json:"last_name"`
	AvatarURL   string     `json:"avatar_url,omitempty"`
	Email       string     `json:"email,omitempty"`
	Phone       string     `json:"phone,omitempty"`
	LevelName   string     `json:"level_name,omitempty"`
	LevelCode   string     `json:"level_code,omitempty"`
	Cycle       string     `json:"cycle,omitempty"`
	Filiere     string     `json:"filiere,omitempty"`
	School      string     `json:"school,omitempty"`
	DateOfBirth *time.Time `json:"date_of_birth,omitempty"`
}

type StudentDashboardResponse struct {
	Profile          StudentProfileResponse `json:"profile"`
	UpcomingSessions []SessionBrief         `json:"upcoming_sessions"`
	TotalSessions    int                    `json:"total_sessions"`
	TotalCourses     int                    `json:"total_courses"`
}

type SessionBrief struct {
	ID          uuid.UUID `json:"id"`
	Title       string    `json:"title"`
	TeacherName string    `json:"teacher_name"`
	StartTime   time.Time `json:"start_time"`
	EndTime     time.Time `json:"end_time"`
	Status      string    `json:"status"`
}

type EnrollmentResponse struct {
	SessionID   uuid.UUID `json:"session_id"`
	Title       string    `json:"title"`
	TeacherName string    `json:"teacher_name"`
	StartTime   time.Time `json:"start_time"`
	Status      string    `json:"status"`
	Attendance  string    `json:"attendance"`
}
