-- +goose Up
-- +goose StatementBegin

-- Deduplicate any existing rows before adding constraint
DELETE FROM session_participants a
USING session_participants b
WHERE a.id > b.id
  AND a.session_id = b.session_id
  AND a.student_id = b.student_id;

-- Add unique constraint so ON CONFLICT DO NOTHING works correctly
ALTER TABLE session_participants
  ADD CONSTRAINT uq_session_student UNIQUE (session_id, student_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE session_participants DROP CONSTRAINT IF EXISTS uq_session_student;
-- +goose StatementEnd
