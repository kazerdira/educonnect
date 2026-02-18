package booking

import "time"

// ─── Responses ──────────────────────────────────────────────────

type BookingRequestResponse struct {
	ID            string  `json:"id"`
	StudentID     string  `json:"student_id"`
	StudentName   string  `json:"student_name"`
	TeacherID     string  `json:"teacher_id"`
	TeacherName   string  `json:"teacher_name"`
	OfferingID    *string `json:"offering_id,omitempty"`
	SubjectName   string  `json:"subject_name,omitempty"`
	LevelName     string  `json:"level_name,omitempty"`
	SessionType   string  `json:"session_type"`   // one_on_one or group
	RequestedDate string  `json:"requested_date"` // YYYY-MM-DD
	StartTime     string  `json:"start_time"`     // HH:MM
	EndTime       string  `json:"end_time"`       // HH:MM
	Message       string  `json:"message,omitempty"`
	Purpose       string  `json:"purpose,omitempty"` // exam_prep, revision, homework, etc.
	Status        string  `json:"status"`            // pending, accepted, declined, cancelled
	DeclineReason string  `json:"decline_reason,omitempty"`
	SessionID     *string `json:"session_id,omitempty"` // Set when accepted
	SeriesID      *string `json:"series_id,omitempty"`  // Set when accepted — the series this booking feeds into
	// Parent booking fields
	BookedByParentID   *string   `json:"booked_by_parent_id,omitempty"`
	BookedByParentName string    `json:"booked_by_parent_name,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// ─── Requests ───────────────────────────────────────────────────

type CreateBookingRequest struct {
	TeacherID     string `json:"teacher_id" binding:"required"`
	OfferingID    string `json:"offering_id,omitempty"`
	SessionType   string `json:"session_type" binding:"required,oneof=individual group"`
	RequestedDate string `json:"requested_date" binding:"required"` // YYYY-MM-DD
	StartTime     string `json:"start_time" binding:"required"`     // HH:MM
	EndTime       string `json:"end_time" binding:"required"`       // HH:MM
	Message       string `json:"message,omitempty"`
	Purpose       string `json:"purpose,omitempty"` // exam_prep, revision, homework, regular, catch_up
	// Parent booking: if set, parent is booking for this child
	ForChildID string `json:"for_child_id,omitempty"`
}

type AcceptBookingRequest struct {
	Title            string  `json:"title,omitempty"`
	Description      string  `json:"description,omitempty"`
	Price            float64 `json:"price" binding:"required,min=0"`
	ExistingSeriesID string  `json:"existing_series_id,omitempty"` // If set, add student to this existing series instead of creating a new one
}

type DeclineBookingRequest struct {
	Reason string `json:"reason" binding:"required,min=5,max=500"`
}

type ListBookingsQuery struct {
	Status string `form:"status"`
	Role   string `form:"role"` // as_student or as_teacher
	Page   int    `form:"page,default=1"`
	Limit  int    `form:"limit,default=20"`
}

// ─── Booking Messages (conversation thread) ────────────────────

type SendMessageRequest struct {
	Content string `json:"content" binding:"required,min=1,max=2000"`
}

type BookingMessageResponse struct {
	ID         string    `json:"id"`
	BookingID  string    `json:"booking_id"`
	SenderID   string    `json:"sender_id"`
	SenderName string    `json:"sender_name"`
	SenderRole string    `json:"sender_role"` // teacher or student
	Content    string    `json:"content"`
	CreatedAt  time.Time `json:"created_at"`
}

type ListMessagesQuery struct {
	Before string `form:"before"` // cursor: created_at ISO timestamp for pagination
	Limit  int    `form:"limit,default=50"`
}
