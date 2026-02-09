-- name: CreateStudentProfile :one
INSERT INTO student_profiles (user_id, level_id, filiere, parent_id, school, date_of_birth, is_independent)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: GetStudentProfile :one
SELECT sp.*, u.first_name, u.last_name, u.avatar_url, u.email, u.phone,
       l.name as level_name, l.code as level_code, l.cycle
FROM student_profiles sp
JOIN users u ON u.id = sp.user_id
LEFT JOIN levels l ON l.id = sp.level_id
WHERE sp.user_id = $1;

-- name: UpdateStudentProfile :one
UPDATE student_profiles SET
    level_id = COALESCE(sqlc.narg('level_id'), level_id),
    filiere = COALESCE(sqlc.narg('filiere'), filiere),
    school = COALESCE(sqlc.narg('school'), school)
WHERE user_id = $1
RETURNING *;

-- name: LinkParent :exec
UPDATE student_profiles SET parent_id = $2 WHERE user_id = $1;

-- name: CreateParentProfile :one
INSERT INTO parent_profiles (user_id)
VALUES ($1)
RETURNING *;

-- name: GetChildrenByParent :many
SELECT sp.*, u.first_name, u.last_name, u.avatar_url,
       l.name as level_name, l.code as level_code
FROM student_profiles sp
JOIN users u ON u.id = sp.user_id
LEFT JOIN levels l ON l.id = sp.level_id
WHERE sp.parent_id = $1
ORDER BY u.first_name;

-- name: GetLevels :many
SELECT * FROM levels ORDER BY "order";

-- name: GetLevelsByCycle :many
SELECT * FROM levels WHERE cycle = $1 ORDER BY "order";

-- name: GetSubjects :many
SELECT * FROM subjects ORDER BY category, name_fr;

-- name: GetSubjectsByLevel :many
SELECT s.*
FROM subjects s
JOIN level_subjects ls ON ls.subject_id = s.id
WHERE ls.level_id = $1
ORDER BY s.category, s.name_fr;

-- name: CreateTransaction :one
INSERT INTO transactions (payer_id, payee_id, session_id, course_id, amount, commission, net_amount, payment_method, description)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: UpdateTransactionStatus :exec
UPDATE transactions SET status = $2, provider_reference = sqlc.narg('provider_reference') WHERE id = $1;

-- name: GetTeacherEarnings :one
SELECT
    COALESCE(SUM(net_amount), 0) as total_earnings,
    COALESCE(SUM(CASE WHEN created_at >= date_trunc('month', NOW()) THEN net_amount ELSE 0 END), 0) as month_earnings,
    COALESCE(SUM(CASE WHEN status = 'completed' AND created_at >= date_trunc('month', NOW()) THEN net_amount ELSE 0 END), 0) as available_balance
FROM transactions
WHERE payee_id = $1 AND status = 'completed';

-- name: GetTeacherTransactions :many
SELECT t.*, u.first_name as payer_name, u.last_name as payer_last_name
FROM transactions t
JOIN users u ON u.id = t.payer_id
WHERE t.payee_id = $1
ORDER BY t.created_at DESC
LIMIT $2 OFFSET $3;

-- name: CreateReview :one
INSERT INTO reviews (session_id, reviewer_id, teacher_id, overall_rating, teaching_quality, communication, punctuality, content_quality, review_text)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: GetTeacherReviews :many
SELECT r.*, u.first_name as reviewer_name, u.last_name as reviewer_last_name, u.avatar_url as reviewer_avatar
FROM reviews r
JOIN users u ON u.id = r.reviewer_id
WHERE r.teacher_id = $1
ORDER BY r.created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetTeacherRatingStats :one
SELECT
    COUNT(*) as total_reviews,
    COALESCE(AVG(overall_rating), 0) as avg_rating,
    COALESCE(AVG(teaching_quality), 0) as avg_teaching,
    COALESCE(AVG(communication), 0) as avg_communication,
    COALESCE(AVG(punctuality), 0) as avg_punctuality,
    COALESCE(AVG(content_quality), 0) as avg_content
FROM reviews
WHERE teacher_id = $1;

-- name: CreateNotification :one
INSERT INTO notifications (user_id, type, title, body, data, channel)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetUserNotifications :many
SELECT * FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: MarkNotificationRead :exec
UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2;

-- name: CountUnreadNotifications :one
SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false;
