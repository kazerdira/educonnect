-- name: CreateUser :one
INSERT INTO users (email, phone, password_hash, role, first_name, last_name, wilaya, language)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1 AND is_active = true;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1 AND is_active = true;

-- name: GetUserByPhone :one
SELECT * FROM users WHERE phone = $1 AND is_active = true;

-- name: UpdateUser :one
UPDATE users SET
    first_name = COALESCE(sqlc.narg('first_name'), first_name),
    last_name = COALESCE(sqlc.narg('last_name'), last_name),
    avatar_url = COALESCE(sqlc.narg('avatar_url'), avatar_url),
    wilaya = COALESCE(sqlc.narg('wilaya'), wilaya),
    language = COALESCE(sqlc.narg('language'), language)
WHERE id = $1
RETURNING *;

-- name: UpdatePassword :exec
UPDATE users SET password_hash = $2 WHERE id = $1;

-- name: VerifyEmail :exec
UPDATE users SET is_email_verified = true WHERE id = $1;

-- name: VerifyPhone :exec
UPDATE users SET is_phone_verified = true WHERE id = $1;

-- name: UpdateLastLogin :exec
UPDATE users SET last_login_at = NOW() WHERE id = $1;

-- name: DeactivateUser :exec
UPDATE users SET is_active = false WHERE id = $1;

-- name: ListUsers :many
SELECT * FROM users
WHERE
    (sqlc.narg('role')::user_role IS NULL OR role = sqlc.narg('role'))
    AND (sqlc.narg('search')::text IS NULL OR
         first_name ILIKE '%' || sqlc.narg('search') || '%' OR
         last_name ILIKE '%' || sqlc.narg('search') || '%' OR
         email ILIKE '%' || sqlc.narg('search') || '%')
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountUsers :one
SELECT COUNT(*) FROM users
WHERE
    (sqlc.narg('role')::user_role IS NULL OR role = sqlc.narg('role'))
    AND is_active = true;

-- name: CreateRefreshToken :exec
INSERT INTO refresh_tokens (user_id, token_hash, device_info, ip_address, expires_at)
VALUES ($1, $2, $3, $4, $5);

-- name: GetRefreshToken :one
SELECT * FROM refresh_tokens WHERE token_hash = $1 AND expires_at > NOW();

-- name: DeleteRefreshToken :exec
DELETE FROM refresh_tokens WHERE token_hash = $1;

-- name: DeleteUserRefreshTokens :exec
DELETE FROM refresh_tokens WHERE user_id = $1;
