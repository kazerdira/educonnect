-- +goose Up
-- EduConnect — Initial Database Schema
-- Aligned with Algerian education system (Primaire, CEM, Lycée)

-- ═══════════════════════════════════════════════════════════════
-- Extensions
-- ═══════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ═══════════════════════════════════════════════════════════════
-- Enums
-- ═══════════════════════════════════════════════════════════════
CREATE TYPE user_role AS ENUM ('teacher', 'parent', 'student', 'admin');
CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected');
CREATE TYPE session_status AS ENUM ('scheduled', 'live', 'completed', 'cancelled');
CREATE TYPE session_type AS ENUM ('one_on_one', 'group');
CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late', 'excused');
CREATE TYPE payment_method AS ENUM ('ccp_baridimob', 'edahabia');
CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'refunded');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired', 'paused');
CREATE TYPE notification_channel AS ENUM ('push', 'in_app', 'sms');
CREATE TYPE education_cycle AS ENUM ('primaire', 'cem', 'lycee');
CREATE TYPE subject_category AS ENUM ('languages', 'sciences', 'humanities', 'technical', 'business', 'other');
CREATE TYPE homework_status AS ENUM ('assigned', 'submitted', 'graded', 'returned');
CREATE TYPE quiz_question_type AS ENUM ('multiple_choice_single', 'multiple_choice_multi', 'true_false', 'short_answer', 'essay', 'fill_blank', 'matching', 'ordering');
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved', 'rejected');

-- ═══════════════════════════════════════════════════════════════
-- Core: Users
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    wilaya VARCHAR(100),
    language VARCHAR(5) DEFAULT 'fr',
    is_active BOOLEAN DEFAULT true,
    is_email_verified BOOLEAN DEFAULT false,
    is_phone_verified BOOLEAN DEFAULT false,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);

-- ═══════════════════════════════════════════════════════════════
-- Education: Levels & Subjects
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,  -- e.g. '1AP', '2AM', '1AS-ST', '3AS-SE'
    cycle education_cycle NOT NULL,
    "order" INT NOT NULL,               -- for sorting
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_fr VARCHAR(200) NOT NULL,
    name_ar VARCHAR(200),
    name_en VARCHAR(200),
    category subject_category NOT NULL DEFAULT 'other',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Which subjects are available at which level
CREATE TABLE level_subjects (
    level_id UUID NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (level_id, subject_id)
);

-- ═══════════════════════════════════════════════════════════════
-- Profiles
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE teacher_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,
    experience_years INT DEFAULT 0,
    verification_status verification_status DEFAULT 'pending',
    verification_note TEXT,             -- reason for rejection
    diploma_urls TEXT[],                -- array of document URLs
    id_document_url TEXT,               -- national ID scan
    specializations TEXT[],
    rating_avg DECIMAL(3,2) DEFAULT 0,
    rating_count INT DEFAULT 0,
    total_sessions INT DEFAULT 0,
    total_students INT DEFAULT 0,
    completion_rate DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_teacher_profiles_user ON teacher_profiles(user_id);
CREATE INDEX idx_teacher_profiles_verification ON teacher_profiles(verification_status);

CREATE TABLE parent_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE student_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    level_id UUID REFERENCES levels(id),
    filiere VARCHAR(20),                -- e.g. 'SE', 'M', 'TM' for Lycée
    parent_id UUID REFERENCES users(id),-- optional parent link
    school VARCHAR(255),
    date_of_birth DATE,
    is_independent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_student_profiles_user ON student_profiles(user_id);
CREATE INDEX idx_student_profiles_parent ON student_profiles(parent_id);

-- ═══════════════════════════════════════════════════════════════
-- Teacher: Offerings & Availability
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE offerings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id),
    level_id UUID NOT NULL REFERENCES levels(id),
    session_type session_type NOT NULL DEFAULT 'one_on_one',
    price_per_hour DECIMAL(10,2) NOT NULL, -- DZD
    max_students INT DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    free_trial_enabled BOOLEAN DEFAULT false,
    free_trial_duration INT DEFAULT 15,    -- minutes
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_offerings_teacher ON offerings(teacher_id);
CREATE INDEX idx_offerings_subject ON offerings(subject_id);
CREATE INDEX idx_offerings_level ON offerings(level_id);

-- Weekly recurring availability slots
CREATE TABLE availability_slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_availability_teacher ON availability_slots(teacher_id);

-- Exception dates (holidays, vacations)
CREATE TABLE availability_exceptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exception_date DATE NOT NULL,
    is_available BOOLEAN DEFAULT false, -- false = day off, true = extra availability
    start_time TIME,                    -- if is_available, specify times
    end_time TIME,
    reason VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- Sessions (LiveKit)
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    offering_id UUID REFERENCES offerings(id),
    teacher_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    actual_start TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    status session_status DEFAULT 'scheduled',
    session_type session_type NOT NULL DEFAULT 'one_on_one',
    max_participants INT DEFAULT 2,
    livekit_room_id VARCHAR(255),
    recording_enabled BOOLEAN DEFAULT false,
    recording_url TEXT,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id),
    price DECIMAL(10,2) NOT NULL,       -- actual price charged
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_teacher ON sessions(teacher_id);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_start ON sessions(start_time);

CREATE TABLE session_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    joined_at TIMESTAMPTZ,
    left_at TIMESTAMPTZ,
    attendance attendance_status DEFAULT 'absent',
    livekit_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_session_participants_session ON session_participants(session_id);
CREATE INDEX idx_session_participants_student ON session_participants(student_id);

-- Post-session notes by teacher
CREATE TABLE session_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    teacher_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- Pre-recorded Content
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    subject_id UUID REFERENCES subjects(id),
    level_id UUID REFERENCES levels(id),
    price DECIMAL(10,2) DEFAULT 0,      -- 0 = free
    is_published BOOLEAN DEFAULT false,
    thumbnail_url TEXT,
    enrollment_count INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_courses_teacher ON courses(teacher_id);

CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    "order" INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    video_url TEXT,
    duration INT DEFAULT 0,             -- seconds
    "order" INT NOT NULL DEFAULT 0,
    is_preview BOOLEAN DEFAULT false,   -- free preview lesson
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE course_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    progress_percent DECIMAL(5,2) DEFAULT 0,
    last_lesson_id UUID REFERENCES lessons(id),
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(course_id, student_id)
);

CREATE TABLE lesson_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    watched_seconds INT DEFAULT 0,
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    UNIQUE(lesson_id, student_id)
);

-- ═══════════════════════════════════════════════════════════════
-- Homework & Quizzes
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE homework (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    instructions TEXT,
    file_urls TEXT[],
    subject_id UUID REFERENCES subjects(id),
    level_id UUID REFERENCES levels(id),
    deadline TIMESTAMPTZ,
    allow_late BOOLEAN DEFAULT false,
    late_penalty_percent DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE homework_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    homework_id UUID NOT NULL REFERENCES homework(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    status homework_status DEFAULT 'assigned',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(homework_id, student_id)
);

CREATE TABLE homework_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    homework_id UUID NOT NULL REFERENCES homework(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    file_urls TEXT[],
    text_content TEXT,
    grade DECIMAL(5,2),
    max_grade DECIMAL(5,2) DEFAULT 20,  -- Algerian system: /20
    feedback TEXT,
    is_late BOOLEAN DEFAULT false,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    graded_at TIMESTAMPTZ
);

CREATE INDEX idx_homework_submissions_student ON homework_submissions(student_id);

CREATE TABLE quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    subject_id UUID REFERENCES subjects(id),
    level_id UUID REFERENCES levels(id),
    time_limit_minutes INT,             -- NULL = untimed
    randomize_questions BOOLEAN DEFAULT false,
    randomize_options BOOLEAN DEFAULT false,
    show_answers_after BOOLEAN DEFAULT true,
    max_attempts INT DEFAULT 1,
    questions JSONB NOT NULL,           -- array of question objects
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE quiz_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id),
    answers JSONB,
    score DECIMAL(5,2),
    max_score DECIMAL(5,2),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    is_graded BOOLEAN DEFAULT false
);

CREATE INDEX idx_quiz_attempts_student ON quiz_attempts(student_id);

-- ═══════════════════════════════════════════════════════════════
-- Payments & Subscriptions
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payer_id UUID NOT NULL REFERENCES users(id),
    payee_id UUID NOT NULL REFERENCES users(id),     -- teacher
    session_id UUID REFERENCES sessions(id),
    course_id UUID REFERENCES courses(id),
    subscription_id UUID,                             -- FK added after subscriptions table
    amount DECIMAL(10,2) NOT NULL,                    -- gross amount in DZD
    commission DECIMAL(10,2) NOT NULL,                -- platform commission
    net_amount DECIMAL(10,2) NOT NULL,                -- teacher receives
    payment_method payment_method NOT NULL,
    status payment_status DEFAULT 'pending',
    provider_reference VARCHAR(255),                  -- external payment reference
    description TEXT,
    refund_amount DECIMAL(10,2) DEFAULT 0,
    refund_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_payer ON transactions(payer_id);
CREATE INDEX idx_transactions_payee ON transactions(payee_id);
CREATE INDEX idx_transactions_status ON transactions(status);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES users(id),
    teacher_id UUID NOT NULL REFERENCES users(id),
    plan_type VARCHAR(50) NOT NULL,                   -- e.g. 'monthly_4', 'monthly_8'
    sessions_per_month INT NOT NULL,
    sessions_used INT DEFAULT 0,
    price DECIMAL(10,2) NOT NULL,                     -- monthly price in DZD
    status subscription_status DEFAULT 'active',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    auto_renew BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_student ON subscriptions(student_id);
CREATE INDEX idx_subscriptions_teacher ON subscriptions(teacher_id);

-- Session packages (buy X sessions at discount)
CREATE TABLE packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    offering_id UUID REFERENCES offerings(id),
    name VARCHAR(255) NOT NULL,
    total_sessions INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,                     -- total package price
    valid_days INT DEFAULT 90,                        -- expiry in days
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE package_purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    package_id UUID NOT NULL REFERENCES packages(id),
    student_id UUID NOT NULL REFERENCES users(id),
    sessions_remaining INT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    transaction_id UUID REFERENCES transactions(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Teacher payouts
CREATE TABLE payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method payment_method NOT NULL,
    account_number VARCHAR(50),                       -- CCP account number
    status payment_status DEFAULT 'pending',
    processed_at TIMESTAMPTZ,
    reference VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- Reviews
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    reviewer_id UUID NOT NULL REFERENCES users(id),   -- student or parent
    teacher_id UUID NOT NULL REFERENCES users(id),
    overall_rating INT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    teaching_quality INT CHECK (teaching_quality BETWEEN 1 AND 5),
    communication INT CHECK (communication BETWEEN 1 AND 5),
    punctuality INT CHECK (punctuality BETWEEN 1 AND 5),
    content_quality INT CHECK (content_quality BETWEEN 1 AND 5),
    review_text TEXT,
    teacher_response TEXT,
    teacher_responded_at TIMESTAMPTZ,
    is_reported BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(session_id, reviewer_id)
);

CREATE INDEX idx_reviews_teacher ON reviews(teacher_id);

-- ═══════════════════════════════════════════════════════════════
-- Notifications
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,          -- 'session_reminder', 'payment_received', etc.
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,                         -- extra payload (session_id, etc.)
    is_read BOOLEAN DEFAULT false,
    channel notification_channel DEFAULT 'in_app',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE is_read = false;

CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    session_reminders BOOLEAN DEFAULT true,
    homework_alerts BOOLEAN DEFAULT true,
    payment_alerts BOOLEAN DEFAULT true,
    marketing BOOLEAN DEFAULT true,
    sms_enabled BOOLEAN DEFAULT true,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- Auth: Refresh Tokens & OTP
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    device_info TEXT,
    ip_address VARCHAR(45),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- ═══════════════════════════════════════════════════════════════
-- Disputes
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    raised_by UUID NOT NULL REFERENCES users(id),
    against UUID NOT NULL REFERENCES users(id),
    reason VARCHAR(50) NOT NULL,         -- 'no_show', 'poor_quality', 'technical'
    description TEXT,
    status dispute_status DEFAULT 'open',
    resolution TEXT,
    resolved_by UUID REFERENCES users(id),
    refund_amount DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- ═══════════════════════════════════════════════════════════════
-- Teacher Promotions
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE promotions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,           -- 'percentage', 'buy_x_get_y', 'fixed'
    value DECIMAL(10,2) NOT NULL,        -- percentage or fixed amount
    buy_quantity INT,                    -- for buy_x_get_y
    free_quantity INT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    usage_count INT DEFAULT 0,
    max_usage INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- Updated_at trigger function
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_teacher_profiles_updated_at BEFORE UPDATE ON teacher_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_parent_profiles_updated_at BEFORE UPDATE ON parent_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_student_profiles_updated_at BEFORE UPDATE ON student_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_offerings_updated_at BEFORE UPDATE ON offerings FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_sessions_updated_at BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_courses_updated_at BEFORE UPDATE ON courses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_homework_updated_at BEFORE UPDATE ON homework FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_quizzes_updated_at BEFORE UPDATE ON quizzes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- +goose Down

-- Drop triggers
DROP TRIGGER IF EXISTS trg_subscriptions_updated_at ON subscriptions;
DROP TRIGGER IF EXISTS trg_transactions_updated_at ON transactions;
DROP TRIGGER IF EXISTS trg_quizzes_updated_at ON quizzes;
DROP TRIGGER IF EXISTS trg_homework_updated_at ON homework;
DROP TRIGGER IF EXISTS trg_courses_updated_at ON courses;
DROP TRIGGER IF EXISTS trg_sessions_updated_at ON sessions;
DROP TRIGGER IF EXISTS trg_offerings_updated_at ON offerings;
DROP TRIGGER IF EXISTS trg_student_profiles_updated_at ON student_profiles;
DROP TRIGGER IF EXISTS trg_parent_profiles_updated_at ON parent_profiles;
DROP TRIGGER IF EXISTS trg_teacher_profiles_updated_at ON teacher_profiles;
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;

DROP FUNCTION IF EXISTS update_updated_at();

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS disputes;
DROP TABLE IF EXISTS notification_preferences;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS payouts;
DROP TABLE IF EXISTS package_purchases;
DROP TABLE IF EXISTS packages;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS quiz_attempts;
DROP TABLE IF EXISTS quizzes;
DROP TABLE IF EXISTS homework_submissions;
DROP TABLE IF EXISTS homework_assignments;
DROP TABLE IF EXISTS homework;
DROP TABLE IF EXISTS lesson_progress;
DROP TABLE IF EXISTS course_enrollments;
DROP TABLE IF EXISTS lessons;
DROP TABLE IF EXISTS chapters;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS session_notes;
DROP TABLE IF EXISTS session_participants;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS availability_exceptions;
DROP TABLE IF EXISTS availability_slots;
DROP TABLE IF EXISTS offerings;
DROP TABLE IF EXISTS student_profiles;
DROP TABLE IF EXISTS parent_profiles;
DROP TABLE IF EXISTS teacher_profiles;
DROP TABLE IF EXISTS level_subjects;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS levels;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;

-- Drop enums
DROP TYPE IF EXISTS dispute_status;
DROP TYPE IF EXISTS quiz_question_type;
DROP TYPE IF EXISTS homework_status;
DROP TYPE IF EXISTS subject_category;
DROP TYPE IF EXISTS education_cycle;
DROP TYPE IF EXISTS notification_channel;
DROP TYPE IF EXISTS subscription_status;
DROP TYPE IF EXISTS payment_status;
DROP TYPE IF EXISTS payment_method;
DROP TYPE IF EXISTS attendance_status;
DROP TYPE IF EXISTS session_type;
DROP TYPE IF EXISTS session_status;
DROP TYPE IF EXISTS verification_status;
DROP TYPE IF EXISTS user_role;
