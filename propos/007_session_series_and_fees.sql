-- Migration: Revised Session & Payment Architecture
-- Adds session_series, session_enrollments, platform_fees tables
-- and modifies existing sessions table

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1. Session Series
-- ═══════════════════════════════════════════════════════════════

CREATE TYPE series_status AS ENUM ('draft', 'active', 'completed', 'cancelled');

CREATE TABLE IF NOT EXISTS session_series (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id      UUID NOT NULL REFERENCES users(id),
    offering_id     UUID REFERENCES offerings(id),
    title           VARCHAR(255) NOT NULL,
    description     TEXT DEFAULT '',
    session_type    VARCHAR(20) NOT NULL CHECK (session_type IN ('individual', 'group')),
    duration_hours  DECIMAL(3,1) NOT NULL CHECK (duration_hours >= 1.0 AND duration_hours <= 4.0),
    min_students    INT NOT NULL DEFAULT 1 CHECK (min_students >= 1),
    max_students    INT NOT NULL DEFAULT 1 CHECK (max_students >= 1 AND max_students <= 50),
    total_sessions  INT NOT NULL DEFAULT 1 CHECK (total_sessions >= 1),
    platform_fee_rate DECIMAL(10,2) NOT NULL, -- 50 DA/h for group, 120 DA/h for individual
    status          series_status NOT NULL DEFAULT 'draft',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_student_range CHECK (max_students >= min_students),
    CONSTRAINT valid_fee_rate CHECK (platform_fee_rate > 0)
);

CREATE INDEX idx_session_series_teacher ON session_series(teacher_id);
CREATE INDEX idx_session_series_status ON session_series(status);

-- ═══════════════════════════════════════════════════════════════
-- 2. Modify sessions table to support series
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS series_id UUID REFERENCES session_series(id);
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS session_number INT DEFAULT 1;

CREATE INDEX idx_sessions_series ON sessions(series_id);

-- ═══════════════════════════════════════════════════════════════
-- 3. Session Enrollments (invitation + enrollment tracking)
-- ═══════════════════════════════════════════════════════════════

CREATE TYPE enrollment_status AS ENUM ('invited', 'accepted', 'declined', 'removed');

CREATE TABLE IF NOT EXISTS session_enrollments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    series_id       UUID REFERENCES session_series(id),
    session_id      UUID REFERENCES sessions(id),
    student_id      UUID NOT NULL REFERENCES users(id),
    invited_by      UUID NOT NULL REFERENCES users(id),
    status          enrollment_status NOT NULL DEFAULT 'invited',
    
    -- Platform fee info
    platform_fee    DECIMAL(10,2) NOT NULL DEFAULT 0,
    fee_paid        BOOLEAN NOT NULL DEFAULT FALSE,
    fee_paid_at     TIMESTAMPTZ,
    fee_payer       VARCHAR(20) CHECK (fee_payer IN ('student', 'teacher')),
    
    -- Timestamps
    invited_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints: one enrollment per student per series or session
    CONSTRAINT uq_series_student UNIQUE (series_id, student_id),
    -- At least one of series_id or session_id must be set
    CONSTRAINT has_target CHECK (series_id IS NOT NULL OR session_id IS NOT NULL)
);

CREATE INDEX idx_enrollments_student ON session_enrollments(student_id);
CREATE INDEX idx_enrollments_series ON session_enrollments(series_id);
CREATE INDEX idx_enrollments_status ON session_enrollments(status);

-- ═══════════════════════════════════════════════════════════════
-- 4. Platform Fee Transactions
-- ═══════════════════════════════════════════════════════════════

CREATE TYPE fee_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

CREATE TABLE IF NOT EXISTS platform_fees (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id   UUID NOT NULL REFERENCES session_enrollments(id),
    payer_id        UUID NOT NULL REFERENCES users(id),
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_method  VARCHAR(30) NOT NULL DEFAULT 'ccp_baridimob',
    status          fee_status NOT NULL DEFAULT 'pending',
    provider_ref    VARCHAR(255),
    description     TEXT DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at         TIMESTAMPTZ
);

CREATE INDEX idx_platform_fees_enrollment ON platform_fees(enrollment_id);
CREATE INDEX idx_platform_fees_payer ON platform_fees(payer_id);
CREATE INDEX idx_platform_fees_status ON platform_fees(status);

COMMIT;
