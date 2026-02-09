-- name: CreateTeacherProfile :one
INSERT INTO teacher_profiles (user_id, bio, experience_years, diploma_urls, id_document_url, specializations)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetTeacherProfile :one
SELECT tp.*, u.first_name, u.last_name, u.avatar_url, u.wilaya, u.phone, u.email
FROM teacher_profiles tp
JOIN users u ON u.id = tp.user_id
WHERE tp.user_id = $1;

-- name: UpdateTeacherProfile :one
UPDATE teacher_profiles SET
    bio = COALESCE(sqlc.narg('bio'), bio),
    experience_years = COALESCE(sqlc.narg('experience_years'), experience_years),
    specializations = COALESCE(sqlc.narg('specializations'), specializations)
WHERE user_id = $1
RETURNING *;

-- name: UpdateVerificationStatus :exec
UPDATE teacher_profiles
SET verification_status = $2, verification_note = $3
WHERE user_id = $1;

-- name: ListPendingVerifications :many
SELECT tp.*, u.first_name, u.last_name, u.email, u.phone, u.created_at as user_created_at
FROM teacher_profiles tp
JOIN users u ON u.id = tp.user_id
WHERE tp.verification_status = 'pending'
ORDER BY tp.created_at ASC
LIMIT $1 OFFSET $2;

-- name: UpdateTeacherStats :exec
UPDATE teacher_profiles SET
    rating_avg = $2,
    rating_count = $3,
    total_sessions = $4,
    total_students = $5,
    completion_rate = $6
WHERE user_id = $1;

-- name: SearchTeachers :many
SELECT tp.*, u.first_name, u.last_name, u.avatar_url, u.wilaya
FROM teacher_profiles tp
JOIN users u ON u.id = tp.user_id
WHERE tp.verification_status = 'verified'
    AND u.is_active = true
    AND (sqlc.narg('wilaya')::text IS NULL OR u.wilaya = sqlc.narg('wilaya'))
    AND (sqlc.narg('min_rating')::decimal IS NULL OR tp.rating_avg >= sqlc.narg('min_rating'))
ORDER BY tp.rating_avg DESC, tp.total_sessions DESC
LIMIT $1 OFFSET $2;

-- name: CreateOffering :one
INSERT INTO offerings (teacher_id, subject_id, level_id, session_type, price_per_hour, max_students, free_trial_enabled, free_trial_duration)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetOfferingsByTeacher :many
SELECT o.*, s.name_fr as subject_name, l.name as level_name, l.code as level_code
FROM offerings o
JOIN subjects s ON s.id = o.subject_id
JOIN levels l ON l.id = o.level_id
WHERE o.teacher_id = $1 AND o.is_active = true
ORDER BY l."order", s.name_fr;

-- name: UpdateOffering :one
UPDATE offerings SET
    price_per_hour = COALESCE(sqlc.narg('price_per_hour'), price_per_hour),
    max_students = COALESCE(sqlc.narg('max_students'), max_students),
    is_active = COALESCE(sqlc.narg('is_active'), is_active),
    free_trial_enabled = COALESCE(sqlc.narg('free_trial_enabled'), free_trial_enabled)
WHERE id = $1 AND teacher_id = $2
RETURNING *;

-- name: DeleteOffering :exec
UPDATE offerings SET is_active = false WHERE id = $1 AND teacher_id = $2;

-- name: GetAvailabilitySlots :many
SELECT * FROM availability_slots
WHERE teacher_id = $1 AND is_active = true
ORDER BY day_of_week, start_time;

-- name: SetAvailabilitySlot :one
INSERT INTO availability_slots (teacher_id, day_of_week, start_time, end_time)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: DeleteAvailabilitySlots :exec
DELETE FROM availability_slots WHERE teacher_id = $1;
