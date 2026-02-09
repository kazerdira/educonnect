package parent

import "time"

// ─── Responses ──────────────────────────────────────────────────

type ChildResponse struct {
	ID          string     `json:"id"`
	FirstName   string     `json:"first_name"`
	LastName    string     `json:"last_name"`
	AvatarURL   string     `json:"avatar_url,omitempty"`
	LevelName   string     `json:"level_name,omitempty"`
	LevelCode   string     `json:"level_code,omitempty"`
	Cycle       string     `json:"cycle,omitempty"`
	Filiere     string     `json:"filiere,omitempty"`
	School      string     `json:"school,omitempty"`
	DateOfBirth *time.Time `json:"date_of_birth,omitempty"`
}

type ParentDashboardResponse struct {
	Children         []ChildResponse `json:"children"`
	TotalChildren    int             `json:"total_children"`
	TotalSessions    int             `json:"total_sessions"`
	UpcomingSessions int             `json:"upcoming_sessions"`
}

// ─── Requests ───────────────────────────────────────────────────

type AddChildRequest struct {
	FirstName   string `json:"first_name" binding:"required,min=2,max=50"`
	LastName    string `json:"last_name" binding:"required,min=2,max=50"`
	LevelCode   string `json:"level_code" binding:"required"`
	Filiere     string `json:"filiere,omitempty"`
	School      string `json:"school,omitempty"`
	DateOfBirth string `json:"date_of_birth,omitempty"`
}

type UpdateChildRequest struct {
	FirstName *string `json:"first_name,omitempty" binding:"omitempty,min=2,max=50"`
	LastName  *string `json:"last_name,omitempty" binding:"omitempty,min=2,max=50"`
	LevelCode *string `json:"level_code,omitempty"`
	School    *string `json:"school,omitempty"`
}
