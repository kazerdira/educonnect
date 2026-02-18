package messaging

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"educonnect/internal/config"

	"github.com/nats-io/nats.go"
)

// NATS wraps the NATS client with JetStream support.
type NATS struct {
	Conn      *nats.Conn
	JetStream nats.JetStreamContext
}

// Subjects for different event types.
const (
	SubjectNotification   = "educonnect.notification"
	SubjectPayment        = "educonnect.payment"
	SubjectSessionEvent   = "educonnect.session"
	SubjectVideoTranscode = "educonnect.transcode"
	SubjectTeacherVerify  = "educonnect.verification"
	SubjectAnalyticsEvent = "educonnect.analytics"
)

// Stream names.
const (
	StreamNotifications = "NOTIFICATIONS"
	StreamPayments      = "PAYMENTS"
	StreamSessions      = "SESSIONS"
	StreamTranscoding   = "TRANSCODING"
)

// NewNATS creates a new NATS connection with JetStream.
func NewNATS(cfg config.NATSConfig) (*NATS, error) {
	opts := []nats.Option{
		nats.MaxReconnects(-1),
		nats.ReconnectWait(2 * time.Second),
		nats.DisconnectErrHandler(func(_ *nats.Conn, err error) {
			slog.Warn("NATS disconnected", "error", err)
		}),
		nats.ReconnectHandler(func(_ *nats.Conn) {
			slog.Info("NATS reconnected")
		}),
	}

	// Only add authentication if credentials are provided
	if cfg.User != "" && cfg.Password != "" {
		opts = append(opts, nats.UserInfo(cfg.User, cfg.Password))
	}

	nc, err := nats.Connect(cfg.URL, opts...)
	if err != nil {
		return nil, fmt.Errorf("nats connect: %w", err)
	}

	// Initialize JetStream
	js, err := nc.JetStream(nats.PublishAsyncMaxPending(256))
	if err != nil {
		nc.Close()
		return nil, fmt.Errorf("jetstream init: %w", err)
	}

	n := &NATS{Conn: nc, JetStream: js}

	// Create streams
	if err := n.createStreams(); err != nil {
		nc.Close()
		return nil, fmt.Errorf("create streams: %w", err)
	}

	return n, nil
}

// createStreams initializes JetStream streams.
func (n *NATS) createStreams() error {
	streams := []struct {
		name     string
		subjects []string
	}{
		{StreamNotifications, []string{"educonnect.notification.>"}},
		{StreamPayments, []string{"educonnect.payment.>"}},
		{StreamSessions, []string{"educonnect.session.>"}},
		{StreamTranscoding, []string{"educonnect.transcode.>"}},
	}

	for _, s := range streams {
		_, err := n.JetStream.AddStream(&nats.StreamConfig{
			Name:      s.name,
			Subjects:  s.subjects,
			Retention: nats.WorkQueuePolicy,
			MaxAge:    24 * time.Hour,
			Storage:   nats.FileStorage,
		})
		if err != nil {
			return fmt.Errorf("create stream %s: %w", s.name, err)
		}
	}

	return nil
}

// Publish publishes a message to a subject.
func (n *NATS) Publish(subject string, payload interface{}) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}

	_, err = n.JetStream.Publish(subject, data)
	return err
}

// Subscribe creates a durable subscription on a subject.
func (n *NATS) Subscribe(subject, durable string, handler func(msg *nats.Msg)) (*nats.Subscription, error) {
	return n.JetStream.Subscribe(subject, handler, nats.Durable(durable), nats.ManualAck())
}

// Close closes the NATS connection.
func (n *NATS) Close() {
	n.Conn.Drain()
	n.Conn.Close()
}
