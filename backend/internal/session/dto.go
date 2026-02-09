package session

// ─── Responses ──────────────────────────────────────────────────

type SessionResponse struct {
	ID           string             `json:"id"`
	TeacherID    string             `json:"teacher_id"`
	TeacherName  string             `json:"teacher_name"`
	Title        string             `json:"title"`
	Description  string             `json:"description,omitempty"`
	SessionType  string             `json:"session_type"`
	StartTime    string             `json:"start_time"`
	EndTime      string             `json:"end_time"`
	MaxStudents  int                `json:"max_students"`
	Price        float64            `json:"price"`
	Status       string             `json:"status"`
	RoomID       string             `json:"room_id,omitempty"`
	RecordingURL string             `json:"recording_url,omitempty"`
	Participants []ParticipantBrief `json:"participants,omitempty"`
}

type ParticipantBrief struct {
	UserID     string `json:"user_id"`
	Name       string `json:"name"`
	Attendance string `json:"attendance"`
}

type JoinSessionResponse struct {
	RoomID    string `json:"room_id"`
	Token     string `json:"token"`
	URL       string `json:"url,omitempty"`
	IsTeacher bool   `json:"is_teacher"`
}

// ─── Requests ───────────────────────────────────────────────────

type CreateSessionRequest struct {
	OfferingID  string  `json:"offering_id"`
	Title       string  `json:"title" binding:"required,min=3,max=200"`
	Description string  `json:"description,omitempty"`
	SessionType string  `json:"session_type" binding:"required"`
	StartTime   string  `json:"start_time" binding:"required"`
	EndTime     string  `json:"end_time" binding:"required"`
	MaxStudents int     `json:"max_students" binding:"required,min=1,max=50"`
	Price       float64 `json:"price" binding:"required"`
}

type RescheduleSessionRequest struct {
	StartTime string `json:"start_time" binding:"required"`
	EndTime   string `json:"end_time" binding:"required"`
}

type CancelSessionRequest struct {
	Reason string `json:"reason" binding:"required,min=5,max=500"`
}

type ListSessionsQuery struct {
	Status string `form:"status"`
	Page   int    `form:"page,default=1"`
	Limit  int    `form:"limit,default=20"`
}
