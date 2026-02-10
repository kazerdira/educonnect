# EduConnect - Revised Session & Payment Architecture

## Overview

This document describes the redesigned session management and payment flow for EduConnect, tailored to the Algerian tutoring market.

---

## Core Concepts

### 1. Offerings (already exists - teacher's catalog)
A teacher creates offerings: what they teach, at what level, price per hour, session type (individual/group), min/max students.

### 2. Session Series vs Single Sessions
- **Single Session**: A one-off class (e.g., exam prep)
- **Session Series**: A recurring set of sessions (e.g., "Math every Sunday & Tuesday for 4 weeks" = 8 sessions)

Both are created by the teacher. A series shares the same `series_id` and students enrolled in the series get access to all sessions in it.

### 3. Invitation Flow
```
Teacher creates session/series
    → Teacher invites specific students
    → Student/Parent receives invitation notification
    → Student/Parent accepts invitation
    → Platform fee is calculated and charged
    → Student gains access to join the session(s)
```

### 4. Payment Model (Platform Fees)

| Session Type | Who Pays the App | Rate |
|---|---|---|
| **Group** (2+ students) | Each student/parent | 50 DA × hours × sessions_count |
| **Individual** (1-on-1) | Teacher | 120 DA × hours × sessions_count |

**Important**: The teacher-student payment for the actual tutoring is handled outside the app (direct arrangement). The app only charges its platform fee.

### 5. Access Control
- Before each session, the app verifies:
  - For **group sessions**: Has the student/parent paid the platform fee?
  - For **individual sessions**: Has the teacher paid the platform fee?
- If not paid → student cannot join the LiveKit room

---

## Database Schema Changes

### New/Modified Tables

```sql
-- Session series (groups multiple sessions together)
CREATE TABLE session_series (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id      UUID NOT NULL REFERENCES users(id),
    offering_id     UUID REFERENCES offerings(id),
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    session_type    VARCHAR(20) NOT NULL CHECK (session_type IN ('individual', 'group')),
    duration_hours  DECIMAL(3,1) NOT NULL CHECK (duration_hours >= 1 AND duration_hours <= 4),
    min_students    INT NOT NULL DEFAULT 1,
    max_students    INT NOT NULL DEFAULT 1,
    total_sessions  INT NOT NULL DEFAULT 1,        -- how many sessions in the series
    platform_fee_rate DECIMAL(10,2) NOT NULL,       -- 50 or 120 DA/hour
    status          VARCHAR(20) NOT NULL DEFAULT 'draft' 
                    CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Individual sessions (each occurrence in a series, or standalone)
-- Modified from current sessions table
ALTER TABLE sessions ADD COLUMN series_id UUID REFERENCES session_series(id);
ALTER TABLE sessions ADD COLUMN session_number INT DEFAULT 1; -- 1st, 2nd, etc. in series

-- Student enrollment in a series (or single session)
CREATE TABLE session_enrollments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    series_id       UUID REFERENCES session_series(id),
    session_id      UUID REFERENCES sessions(id),    -- NULL if enrolled in whole series
    student_id      UUID NOT NULL REFERENCES users(id),
    invited_by      UUID NOT NULL REFERENCES users(id), -- teacher who invited
    status          VARCHAR(20) NOT NULL DEFAULT 'invited'
                    CHECK (status IN ('invited', 'accepted', 'declined', 'removed')),
    platform_fee    DECIMAL(10,2) NOT NULL DEFAULT 0,  -- calculated total fee
    fee_paid        BOOLEAN NOT NULL DEFAULT FALSE,
    fee_paid_at     TIMESTAMPTZ,
    fee_payer       VARCHAR(20) CHECK (fee_payer IN ('student', 'teacher')),
    invited_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- A student can only be enrolled once per series/session
    UNIQUE(series_id, student_id),
    UNIQUE(session_id, student_id)
);

-- Platform fee transactions (separate from teacher-student payments)
CREATE TABLE platform_fees (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id   UUID NOT NULL REFERENCES session_enrollments(id),
    payer_id        UUID NOT NULL REFERENCES users(id),  -- student or teacher
    amount          DECIMAL(10,2) NOT NULL,
    payment_method  VARCHAR(30) NOT NULL DEFAULT 'ccp_baridimob',
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    provider_ref    VARCHAR(255),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at         TIMESTAMPTZ
);
```

---

## API Endpoints

### Session Series
```
POST   /api/v1/sessions/series              - Create a session series (or single)
GET    /api/v1/sessions/series               - List my series (teacher)
GET    /api/v1/sessions/series/:id           - Get series details
PUT    /api/v1/sessions/series/:id           - Update series
DELETE /api/v1/sessions/series/:id           - Cancel series
POST   /api/v1/sessions/series/:id/sessions  - Add sessions to series (with dates)
```

### Invitations
```
POST   /api/v1/sessions/series/:id/invite    - Invite students to series
GET    /api/v1/invitations                    - List my invitations (student/parent)
PUT    /api/v1/invitations/:id/accept         - Accept invitation
PUT    /api/v1/invitations/:id/decline        - Decline invitation
```

### Platform Fees
```
GET    /api/v1/fees/pending                   - My pending fees
POST   /api/v1/fees/:id/pay                   - Pay platform fee (BaridiMob)
POST   /api/v1/fees/:id/confirm               - Confirm payment with provider ref
```

### Session Access
```
POST   /api/v1/sessions/:id/join              - Join a live session (checks fee status)
```

---

## Flow Examples

### Example 1: Teacher creates a month of group classes

1. Teacher creates series: "Math 3AM - January" (group, 2h, 8 sessions, min 3, max 15 students)
2. Teacher adds 8 session dates (every Sunday & Tuesday)
3. Teacher invites 10 students
4. Each student receives notification
5. Student accepts → platform calculates fee: 50 DA × 2h × 8 sessions = 800 DA
6. Student pays 800 DA via BaridiMob
7. Student can now join any session in the series

### Example 2: Teacher creates individual session

1. Teacher creates series: "Physics revision" (individual, 1.5h, 1 session)
2. Teacher invites 1 student
3. Student accepts (no fee for student)
4. Platform calculates teacher fee: 120 DA × 1.5h × 1 = 180 DA
5. Teacher pays 180 DA via BaridiMob
6. Student can join the session

---

## Fee Calculation Formula

```
For GROUP sessions:
  student_fee = 50 DA × duration_hours × total_sessions_in_series

For INDIVIDUAL sessions:
  teacher_fee = 120 DA × duration_hours × total_sessions_in_series
  student_fee = 0 DA
```

---

## Access Control Logic (on Join)

```go
func canJoinSession(enrollment, session) bool {
    if session.Type == "group" {
        // Student must have paid their platform fee
        return enrollment.FeePaid
    }
    if session.Type == "individual" {
        // Teacher must have paid the platform fee for this enrollment
        return enrollment.FeePaid  // fee_payer = 'teacher'
    }
    return false
}
```
