-- +goose Up
-- +goose StatementBegin

-- Link booking requests to session series (not just individual sessions)
-- When a teacher accepts a booking, a series is created (or existing one reused)
ALTER TABLE booking_requests ADD COLUMN IF NOT EXISTS series_id UUID REFERENCES session_series(id);
CREATE INDEX IF NOT EXISTS idx_booking_requests_series ON booking_requests(series_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_booking_requests_series;
ALTER TABLE booking_requests DROP COLUMN IF EXISTS series_id;
-- +goose StatementEnd
