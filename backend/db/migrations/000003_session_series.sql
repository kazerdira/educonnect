-- Migration: Session Series & Platform Fees
-- Teacher-only payment model: Teacher pays platform fee before starting sessions
-- Students enroll for free (they pay the teacher directly outside the app)

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1. Enums
-- ═══════════════════════════════════════════════════════════════

CREATE TYPE series_status AS ENUM ('draft', 'active', 'finalized', 'completed', 'cancelled');
CREATE TYPE enrollment_status AS ENUM ('invited', 'requested', 'accepted', 'declined', 'removed');
CREATE TYPE platform_fee_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

-- ═══════════════════════════════════════════════════════════════
-- 2. Session Series (groups multiple sessions or single session)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE session_series (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    offering_id     UUID REFERENCES offerings(id),
    title           VARCHAR(255) NOT NULL,
    description     TEXT DEFAULT '',
    session_type    session_type NOT NULL DEFAULT 'group',  -- 'one_on_one' or 'group'
    duration_hours  DECIMAL(3,1) NOT NULL CHECK (duration_hours >= 1.0 AND duration_hours <= 4.0),
    min_students    INT NOT NULL DEFAULT 1 CHECK (min_students >= 1),
    max_students    INT NOT NULL DEFAULT 1 CHECK (max_students >= 1 AND max_students <= 50),
    price_per_hour  DECIMAL(10,2) NOT NULL DEFAULT 0,  -- Teacher's rate (for display/info)
    status          series_status NOT NULL DEFAULT 'draft',
    is_finalized    BOOLEAN NOT NULL DEFAULT FALSE,
    finalized_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_student_range CHECK (max_students >= min_students)
);

CREATE INDEX idx_session_series_teacher ON session_series(teacher_id);
CREATE INDEX idx_session_series_status ON session_series(status);
CREATE INDEX idx_session_series_created ON session_series(created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- 3. Link sessions to series (modify existing sessions table)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS series_id UUID REFERENCES session_series(id) ON DELETE CASCADE;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS session_number INT DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_sessions_series ON sessions(series_id);

-- ═══════════════════════════════════════════════════════════════
-- 4. Session Enrollments (invitation + request system)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE session_enrollments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    series_id       UUID NOT NULL REFERENCES session_series(id) ON DELETE CASCADE,
    student_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    initiated_by    VARCHAR(10) NOT NULL CHECK (initiated_by IN ('teacher', 'student')),
    status          enrollment_status NOT NULL DEFAULT 'invited',
    invited_at      TIMESTAMPTZ,   -- When teacher invited
    requested_at    TIMESTAMPTZ,   -- When student requested
    accepted_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- One enrollment per student per series
    CONSTRAINT uq_series_student UNIQUE (series_id, student_id)
);

CREATE INDEX idx_enrollments_student ON session_enrollments(student_id);
CREATE INDEX idx_enrollments_series ON session_enrollments(series_id);
CREATE INDEX idx_enrollments_status ON session_enrollments(status);

-- ═══════════════════════════════════════════════════════════════
-- 5. Platform Fees (Teacher pays to unlock sessions)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE platform_fees (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    series_id       UUID NOT NULL REFERENCES session_series(id) ON DELETE CASCADE,
    teacher_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    enrolled_count  INT NOT NULL DEFAULT 0,         -- Snapshot of enrolled students at payment time
    total_sessions  INT NOT NULL DEFAULT 1,         -- Snapshot of session count
    duration_hours  DECIMAL(3,1) NOT NULL,          -- Snapshot of duration
    fee_rate        DECIMAL(10,2) NOT NULL,         -- 50 DA/h (group) or 120 DA/h (individual)
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_method  VARCHAR(30) NOT NULL DEFAULT 'ccp_baridimob',
    status          platform_fee_status NOT NULL DEFAULT 'pending',
    provider_ref    VARCHAR(255),                   -- BaridiMob transaction reference
    admin_verified_by UUID REFERENCES users(id),   -- Admin who verified payment
    admin_notes     TEXT,
    description     TEXT DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at         TIMESTAMPTZ
);

CREATE INDEX idx_platform_fees_series ON platform_fees(series_id);
CREATE INDEX idx_platform_fees_teacher ON platform_fees(teacher_id);
CREATE INDEX idx_platform_fees_status ON platform_fees(status);

-- ═══════════════════════════════════════════════════════════════
-- 6. Constants reference (stored as comment for documentation)
-- ═══════════════════════════════════════════════════════════════
-- GROUP fee:       50 DA × hours × sessions × enrolled_students
-- INDIVIDUAL fee: 120 DA × hours × sessions
-- Teacher always pays, students pay nothing to platform

COMMIT;
