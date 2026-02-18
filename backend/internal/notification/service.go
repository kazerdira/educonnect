package notification

import (
	"context"
	"errors"
	"fmt"

	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrNotificationNotFound = errors.New("notification not found")
	ErrNotAuthorized        = errors.New("not authorized")
)

type Service struct {
	db *database.Postgres
}

func NewService(db *database.Postgres) *Service {
	return &Service{db: db}
}

// CreateNotification inserts an in-app notification for a user.
// This is a reusable helper called from other services.
func (s *Service) CreateNotification(ctx context.Context, userID uuid.UUID, notifType, title, body string, data map[string]interface{}) error {
	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO notifications (user_id, type, title, body, data, channel)
		 VALUES ($1, $2, $3, $4, $5, 'in_app')`,
		userID, notifType, title, body, data,
	)
	if err != nil {
		return fmt.Errorf("create notification: %w", err)
	}
	return nil
}

// ─── ListNotifications ──────────────────────────────────────────

func (s *Service) ListNotifications(ctx context.Context, userID string, limit, offset int, unreadOnly bool) ([]NotificationResponse, int, error) {
	uid, _ := uuid.Parse(userID)

	// Count
	countQ := `SELECT COUNT(*) FROM notifications WHERE user_id = $1`
	args := []interface{}{uid}
	if unreadOnly {
		countQ += ` AND is_read = false`
	}
	var total int
	if err := s.db.Pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count notifications: %w", err)
	}

	// List
	q := `SELECT id, user_id, type, title, body, data, is_read, channel::text, created_at
	      FROM notifications WHERE user_id = $1`
	if unreadOnly {
		q += ` AND is_read = false`
	}
	q += ` ORDER BY created_at DESC LIMIT $2 OFFSET $3`

	rows, err := s.db.Pool.Query(ctx, q, uid, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("query notifications: %w", err)
	}
	defer rows.Close()

	var notifications []NotificationResponse
	for rows.Next() {
		var n NotificationResponse
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body,
			&n.Data, &n.IsRead, &n.Channel, &n.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan notification: %w", err)
		}
		notifications = append(notifications, n)
	}

	if notifications == nil {
		notifications = []NotificationResponse{}
	}

	return notifications, total, nil
}

// ─── MarkRead ───────────────────────────────────────────────────

func (s *Service) MarkRead(ctx context.Context, userID string, notifID string) error {
	uid, _ := uuid.Parse(userID)
	nid, _ := uuid.Parse(notifID)

	tag, err := s.db.Pool.Exec(ctx,
		`UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`,
		nid, uid,
	)
	if err != nil {
		return fmt.Errorf("update notification: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotificationNotFound
	}

	return nil
}

// ─── GetPreferences ─────────────────────────────────────────────

func (s *Service) GetPreferences(ctx context.Context, userID string) (*PreferencesResponse, error) {
	uid, _ := uuid.Parse(userID)

	var p PreferencesResponse
	err := s.db.Pool.QueryRow(ctx,
		`SELECT user_id, session_reminders, homework_alerts, payment_alerts,
		    marketing, sms_enabled, quiet_hours_start::text, quiet_hours_end::text
		 FROM notification_preferences WHERE user_id = $1`, uid,
	).Scan(
		&p.UserID, &p.SessionReminders, &p.HomeworkAlerts, &p.PaymentAlerts,
		&p.Marketing, &p.SmsEnabled, &p.QuietHoursStart, &p.QuietHoursEnd,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Return defaults
			return &PreferencesResponse{
				UserID:           uid,
				SessionReminders: true,
				HomeworkAlerts:   true,
				PaymentAlerts:    true,
				Marketing:        true,
				SmsEnabled:       true,
			}, nil
		}
		return nil, fmt.Errorf("query preferences: %w", err)
	}

	return &p, nil
}

// ─── UpdatePreferences ──────────────────────────────────────────

func (s *Service) UpdatePreferences(ctx context.Context, userID string, req UpdatePreferencesRequest) (*PreferencesResponse, error) {
	uid, _ := uuid.Parse(userID)

	// Upsert
	_, err := s.db.Pool.Exec(ctx,
		`INSERT INTO notification_preferences (user_id)
		 VALUES ($1)
		 ON CONFLICT (user_id) DO NOTHING`, uid,
	)
	if err != nil {
		return nil, fmt.Errorf("ensure preferences row: %w", err)
	}

	// Build dynamic update
	setClauses := []string{}
	args := []interface{}{}
	argIdx := 1

	addClause := func(field string, val interface{}) {
		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", field, argIdx))
		args = append(args, val)
		argIdx++
	}

	if req.SessionReminders != nil {
		addClause("session_reminders", *req.SessionReminders)
	}
	if req.HomeworkAlerts != nil {
		addClause("homework_alerts", *req.HomeworkAlerts)
	}
	if req.PaymentAlerts != nil {
		addClause("payment_alerts", *req.PaymentAlerts)
	}
	if req.Marketing != nil {
		addClause("marketing", *req.Marketing)
	}
	if req.SmsEnabled != nil {
		addClause("sms_enabled", *req.SmsEnabled)
	}
	if req.QuietHoursStart != nil {
		addClause("quiet_hours_start", *req.QuietHoursStart)
	}
	if req.QuietHoursEnd != nil {
		addClause("quiet_hours_end", *req.QuietHoursEnd)
	}

	if len(setClauses) > 0 {
		q := "UPDATE notification_preferences SET "
		for i, clause := range setClauses {
			if i > 0 {
				q += ", "
			}
			q += clause
		}
		q += fmt.Sprintf(" WHERE user_id = $%d", argIdx)
		args = append(args, uid)

		if _, err := s.db.Pool.Exec(ctx, q, args...); err != nil {
			return nil, fmt.Errorf("update preferences: %w", err)
		}
	}

	return s.GetPreferences(ctx, userID)
}
