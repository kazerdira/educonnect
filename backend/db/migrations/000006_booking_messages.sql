-- +migrate Up
-- Booking conversation messages: teacher ↔ student negotiate before accept/decline

CREATE TABLE IF NOT EXISTS booking_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id  UUID NOT NULL REFERENCES booking_requests(id) ON DELETE CASCADE,
    sender_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content     TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_booking_messages_booking_id ON booking_messages(booking_id, created_at);
CREATE INDEX idx_booking_messages_sender_id  ON booking_messages(sender_id);
