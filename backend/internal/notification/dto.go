package notification

import (
	"time"

	"github.com/google/uuid"
)

// ─── Notification ───────────────────────────────────────────────

type NotificationResponse struct {
	ID        uuid.UUID              `json:"id"`
	UserID    uuid.UUID              `json:"user_id"`
	Type      string                 `json:"type"`
	Title     string                 `json:"title"`
	Body      string                 `json:"body"`
	Data      map[string]interface{} `json:"data,omitempty"`
	IsRead    bool                   `json:"is_read"`
	Channel   string                 `json:"channel"`
	CreatedAt time.Time              `json:"created_at"`
}

// ─── Preferences ────────────────────────────────────────────────

type PreferencesResponse struct {
	UserID           uuid.UUID `json:"user_id"`
	SessionReminders bool      `json:"session_reminders"`
	HomeworkAlerts   bool      `json:"homework_alerts"`
	PaymentAlerts    bool      `json:"payment_alerts"`
	Marketing        bool      `json:"marketing"`
	SmsEnabled       bool      `json:"sms_enabled"`
	QuietHoursStart  *string   `json:"quiet_hours_start,omitempty"`
	QuietHoursEnd    *string   `json:"quiet_hours_end,omitempty"`
}

type UpdatePreferencesRequest struct {
	SessionReminders *bool   `json:"session_reminders,omitempty"`
	HomeworkAlerts   *bool   `json:"homework_alerts,omitempty"`
	PaymentAlerts    *bool   `json:"payment_alerts,omitempty"`
	Marketing        *bool   `json:"marketing,omitempty"`
	SmsEnabled       *bool   `json:"sms_enabled,omitempty"`
	QuietHoursStart  *string `json:"quiet_hours_start,omitempty"`
	QuietHoursEnd    *string `json:"quiet_hours_end,omitempty"`
}
