-- name: CreateSession :one
INSERT INTO sessions (offering_id, teacher_id, title, description, start_time, end_time, session_type, max_participants, recording_enabled, price)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: GetSession :one
SELECT s.*, u.first_name as teacher_first_name, u.last_name as teacher_last_name
FROM sessions s
JOIN users u ON u.id = s.teacher_id
WHERE s.id = $1;

-- name: UpdateSessionStatus :exec
UPDATE sessions SET status = $2 WHERE id = $1;

-- name: StartSession :exec
UPDATE sessions SET status = 'live', actual_start = NOW(), livekit_room_id = $2 WHERE id = $1;

-- name: EndSession :exec
UPDATE sessions SET status = 'completed', actual_end = NOW(), recording_url = sqlc.narg('recording_url') WHERE id = $1;

-- name: CancelSession :exec
UPDATE sessions SET status = 'cancelled', cancellation_reason = $2, cancelled_by = $3 WHERE id = $1;

-- name: ListTeacherSessions :many
SELECT s.*, COUNT(sp.id) as participant_count
FROM sessions s
LEFT JOIN session_participants sp ON sp.session_id = s.id
WHERE s.teacher_id = $1
    AND (sqlc.narg('status')::session_status IS NULL OR s.status = sqlc.narg('status'))
    AND (sqlc.narg('from_date')::timestamptz IS NULL OR s.start_time >= sqlc.narg('from_date'))
    AND (sqlc.narg('to_date')::timestamptz IS NULL OR s.start_time <= sqlc.narg('to_date'))
GROUP BY s.id
ORDER BY s.start_time DESC
LIMIT $2 OFFSET $3;

-- name: ListStudentSessions :many
SELECT s.*, u.first_name as teacher_first_name, u.last_name as teacher_last_name
FROM sessions s
JOIN session_participants sp ON sp.session_id = s.id
JOIN users u ON u.id = s.teacher_id
WHERE sp.student_id = $1
    AND (sqlc.narg('status')::session_status IS NULL OR s.status = sqlc.narg('status'))
ORDER BY s.start_time DESC
LIMIT $2 OFFSET $3;

-- name: AddSessionParticipant :one
INSERT INTO session_participants (session_id, student_id)
VALUES ($1, $2)
RETURNING *;

-- name: UpdateParticipantAttendance :exec
UPDATE session_participants SET
    joined_at = COALESCE(sqlc.narg('joined_at'), joined_at),
    left_at = COALESCE(sqlc.narg('left_at'), left_at),
    attendance = COALESCE(sqlc.narg('attendance'), attendance)
WHERE session_id = $1 AND student_id = $2;

-- name: GetSessionParticipants :many
SELECT sp.*, u.first_name, u.last_name, u.avatar_url
FROM session_participants sp
JOIN users u ON u.id = sp.student_id
WHERE sp.session_id = $1;

-- name: GetUpcomingSessions :many
SELECT s.*, COUNT(sp.id) as participant_count
FROM sessions s
LEFT JOIN session_participants sp ON sp.session_id = s.id
WHERE s.teacher_id = $1
    AND s.status = 'scheduled'
    AND s.start_time > NOW()
GROUP BY s.id
ORDER BY s.start_time ASC
LIMIT $2;

-- name: CreateSessionNote :one
INSERT INTO session_notes (session_id, student_id, teacher_id, content)
VALUES ($1, $2, $3, $4)
RETURNING *;
