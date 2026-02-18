-- +goose Up
-- +goose StatementBegin

-- ═══════════════════════════════════════════════════════════════
-- Teacher Wallet & Star-based Enrollment Fee System
-- ═══════════════════════════════════════════════════════════════
-- Replaces the old platform_fees flow.
-- Teachers pre-purchase credits (DZD) into a wallet.
-- Each enrollment acceptance costs 1 "star":
--   • Group enrollment  → 50 DZD per star
--   • Private (1-on-1)  → 70 DZD per star
-- Star deducted at acceptance; refundable before 1st session.
-- ═══════════════════════════════════════════════════════════════

-- 1. Enums
CREATE TYPE wallet_tx_type   AS ENUM ('purchase', 'star_deduction', 'refund');
CREATE TYPE wallet_tx_status AS ENUM ('pending', 'completed', 'failed');

-- 2. Teacher Wallets (one per teacher)
CREATE TABLE teacher_wallets (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id       UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    balance          DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    total_purchased  DECIMAL(12,2) NOT NULL DEFAULT 0,  -- lifetime DZD added
    total_spent      DECIMAL(12,2) NOT NULL DEFAULT 0,  -- lifetime DZD spent on stars
    total_refunded   DECIMAL(12,2) NOT NULL DEFAULT 0,  -- lifetime DZD refunded
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_teacher_wallets_teacher ON teacher_wallets(teacher_id);

-- 3. Credit Packages (admin-managed price tiers)
CREATE TABLE credit_packages (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(100) NOT NULL,
    amount       DECIMAL(10,2) NOT NULL CHECK (amount > 0),     -- DZD price
    bonus        DECIMAL(10,2) NOT NULL DEFAULT 0,              -- bonus credits
    total_credits DECIMAL(10,2) GENERATED ALWAYS AS (amount + bonus) STORED,
    is_active    BOOLEAN NOT NULL DEFAULT true,
    sort_order   INT NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Wallet Transactions (full audit trail)
CREATE TABLE wallet_transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id       UUID NOT NULL REFERENCES teacher_wallets(id) ON DELETE CASCADE,
    type            wallet_tx_type   NOT NULL,
    status          wallet_tx_status NOT NULL DEFAULT 'pending',
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),   -- always positive
    balance_after   DECIMAL(12,2) NOT NULL DEFAULT 0,            -- snapshot after apply
    description     TEXT NOT NULL DEFAULT '',
    -- For purchases: payment details
    package_id      UUID REFERENCES credit_packages(id),
    payment_method  VARCHAR(30),
    provider_ref    VARCHAR(255),
    admin_id        UUID REFERENCES users(id),   -- admin who approved/rejected
    admin_notes     TEXT,
    -- For star_deduction / refund: enrollment reference
    enrollment_id   UUID REFERENCES session_enrollments(id),
    series_id       UUID REFERENCES session_series(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wallet_tx_wallet   ON wallet_transactions(wallet_id);
CREATE INDEX idx_wallet_tx_type     ON wallet_transactions(type);
CREATE INDEX idx_wallet_tx_status   ON wallet_transactions(status);
CREATE INDEX idx_wallet_tx_created  ON wallet_transactions(created_at DESC);
CREATE INDEX idx_wallet_tx_enroll   ON wallet_transactions(enrollment_id) WHERE enrollment_id IS NOT NULL;

-- 5. Trigger: auto-update teacher_wallets.updated_at
CREATE TRIGGER trigger_teacher_wallets_updated
    BEFORE UPDATE ON teacher_wallets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 6. Seed default credit packages
INSERT INTO credit_packages (name, amount, bonus, sort_order) VALUES
    ('Starter',  600,    0, 1),
    ('Standard', 1000,  20, 2),
    ('Pro',      2000, 100, 3),
    ('Premium',  5000, 400, 4);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TRIGGER IF EXISTS trigger_teacher_wallets_updated ON teacher_wallets;
DROP TABLE IF EXISTS wallet_transactions;
DROP TABLE IF EXISTS credit_packages;
DROP TABLE IF EXISTS teacher_wallets;
DROP TYPE IF EXISTS wallet_tx_status;
DROP TYPE IF EXISTS wallet_tx_type;
-- +goose StatementEnd
