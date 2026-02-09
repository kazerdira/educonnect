#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════════
# EduConnect — API Smoke Test Suite
# Tests all 39 implemented endpoints end-to-end
# ═══════════════════════════════════════════════════════════════

$BASE = "http://localhost:8080"
$pass = 0
$fail = 0
$errors = @()

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Uri,
        [string]$Body = $null,
        [hashtable]$Headers = @{},
        [int[]]$ExpectedStatus = @(200, 201),
        [string]$ContentType = "application/json"
    )

    try {
        $params = @{
            Uri    = "$BASE$Uri"
            Method = $Method
            Headers = $Headers
            ErrorAction = "Stop"
        }
        if ($Body) {
            $params.Body = $Body
            $params.ContentType = $ContentType
        }

        $resp = Invoke-WebRequest @params
        $status = $resp.StatusCode

        if ($status -in $ExpectedStatus) {
            Write-Host "  ✅ $Name ($status)" -ForegroundColor Green
            $script:pass++
            return ($resp.Content | ConvertFrom-Json)
        } else {
            Write-Host "  ❌ $Name — unexpected status $status" -ForegroundColor Red
            $script:fail++
            $script:errors += "$Name → status $status"
            return $null
        }
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        $detail = ""
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $detail = $reader.ReadToEnd()
        } catch {}

        # Some tests expect non-2xx (e.g. 401, 404) — check
        if ($status -in $ExpectedStatus) {
            Write-Host "  ✅ $Name ($status — expected)" -ForegroundColor Green
            $script:pass++
            return $null
        }

        Write-Host "  ❌ $Name — HTTP $status : $detail" -ForegroundColor Red
        $script:fail++
        $script:errors += "$Name → HTTP $status : $($detail.Substring(0, [Math]::Min(120, $detail.Length)))"
        return $null
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  EduConnect API Smoke Tests" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ─── 0. Health ───────────────────────────────────────────────
Write-Host "📌 Health Check" -ForegroundColor Yellow
Test-Endpoint -Name "GET /health" -Method GET -Uri "/health"

# ─── 1. Auth — Register 3 user types ────────────────────────
Write-Host "`n📌 Auth — Registration" -ForegroundColor Yellow

$teacherBody = @{
    email = "smoke.teacher@test.dz"
    phone = "+213550100001"
    password = "SmokeTe$t1234!"
    first_name = "Karim"
    last_name = "Meziane"
    wilaya = "Alger"
    bio = "Professeur de maths, 10 ans d'experience"
    experience_years = 10
} | ConvertTo-Json

$teacherResp = Test-Endpoint -Name "POST /auth/register/teacher" -Method POST -Uri "/api/v1/auth/register/teacher" -Body $teacherBody -ExpectedStatus @(201)

$parentBody = @{
    email = "smoke.parent@test.dz"
    phone = "+213550100002"
    password = "SmokeTe$t1234!"
    first_name = "Fatima"
    last_name = "Bouzid"
    wilaya = "Oran"
} | ConvertTo-Json

$parentResp = Test-Endpoint -Name "POST /auth/register/parent" -Method POST -Uri "/api/v1/auth/register/parent" -Body $parentBody -ExpectedStatus @(201)

$studentBody = @{
    email = "smoke.student@test.dz"
    phone = "+213550100003"
    password = "SmokeTe$t1234!"
    first_name = "Yacine"
    last_name = "Hadj"
    wilaya = "Constantine"
} | ConvertTo-Json

$studentResp = Test-Endpoint -Name "POST /auth/register/student" -Method POST -Uri "/api/v1/auth/register/student" -Body $studentBody -ExpectedStatus @(201)

# Extract tokens
$teacherToken = $teacherResp.data.access_token
$parentToken  = $parentResp.data.access_token
$studentToken = $studentResp.data.access_token
$teacherId    = $teacherResp.data.user.id
$refreshToken = $teacherResp.data.refresh_token

$tAuth = @{ Authorization = "Bearer $teacherToken" }
$pAuth = @{ Authorization = "Bearer $parentToken" }
$sAuth = @{ Authorization = "Bearer $studentToken" }

# ─── 2. Auth — Login ────────────────────────────────────────
Write-Host "`n📌 Auth — Login & Token" -ForegroundColor Yellow

$loginBody = @{
    email = "smoke.teacher@test.dz"
    password = "SmokeTe$t1234!"
} | ConvertTo-Json

$loginResp = Test-Endpoint -Name "POST /auth/login" -Method POST -Uri "/api/v1/auth/login" -Body $loginBody
if ($loginResp) { $teacherToken = $loginResp.data.access_token; $tAuth = @{ Authorization = "Bearer $teacherToken" } }

# Phone login (sends OTP — expect success message)
$phoneBody = @{ phone = "+213550100001" } | ConvertTo-Json
Test-Endpoint -Name "POST /auth/login/phone" -Method POST -Uri "/api/v1/auth/login/phone" -Body $phoneBody

# Verify OTP (will likely fail with invalid code — expect 401)
$otpBody = @{ phone = "+213550100001"; code = "000000" } | ConvertTo-Json
Test-Endpoint -Name "POST /auth/verify-otp (invalid)" -Method POST -Uri "/api/v1/auth/verify-otp" -Body $otpBody -ExpectedStatus @(401)

# Refresh token
$refreshBody = @{ refresh_token = $refreshToken } | ConvertTo-Json
$refreshResp = Test-Endpoint -Name "POST /auth/refresh" -Method POST -Uri "/api/v1/auth/refresh" -Body $refreshBody
if ($refreshResp) { $teacherToken = $refreshResp.data.access_token; $tAuth = @{ Authorization = "Bearer $teacherToken" } }

# ─── 3. User ────────────────────────────────────────────────
Write-Host "`n📌 User Module" -ForegroundColor Yellow

Test-Endpoint -Name "GET /users/me (teacher)" -Method GET -Uri "/api/v1/users/me" -Headers $tAuth
Test-Endpoint -Name "GET /users/me (parent)" -Method GET -Uri "/api/v1/users/me" -Headers $pAuth
Test-Endpoint -Name "GET /users/me (student)" -Method GET -Uri "/api/v1/users/me" -Headers $sAuth

# Unauthenticated — should fail
Test-Endpoint -Name "GET /users/me (no token → 401)" -Method GET -Uri "/api/v1/users/me" -ExpectedStatus @(401)

$updateBody = @{ first_name = "Karim-Updated"; language = "ar" } | ConvertTo-Json
Test-Endpoint -Name "PUT /users/me" -Method PUT -Uri "/api/v1/users/me" -Body $updateBody -Headers $tAuth

$pwBody = @{ old_password = "SmokeTe$t1234!"; new_password = "NewPass9876!" } | ConvertTo-Json
Test-Endpoint -Name "PUT /users/me/password" -Method PUT -Uri "/api/v1/users/me/password" -Body $pwBody -Headers $tAuth

# Re-login with new password to get fresh token
$loginBody2 = @{ email = "smoke.teacher@test.dz"; password = "NewPass9876!" } | ConvertTo-Json
$loginResp2 = Test-Endpoint -Name "POST /auth/login (new pw)" -Method POST -Uri "/api/v1/auth/login" -Body $loginBody2
if ($loginResp2) { $teacherToken = $loginResp2.data.access_token; $tAuth = @{ Authorization = "Bearer $teacherToken" } }

# ─── 4. Teacher ─────────────────────────────────────────────
Write-Host "`n📌 Teacher Module" -ForegroundColor Yellow

Test-Endpoint -Name "GET /teachers" -Method GET -Uri "/api/v1/teachers" -Headers $tAuth
Test-Endpoint -Name "GET /teachers/:id" -Method GET -Uri "/api/v1/teachers/$teacherId" -Headers $tAuth
Test-Endpoint -Name "GET /teachers/:id (404)" -Method GET -Uri "/api/v1/teachers/00000000-0000-0000-0000-000000000000" -Headers $tAuth -ExpectedStatus @(404, 500)

$updateTeacher = @{ bio = "Updated bio via smoke test"; experience_years = 12 } | ConvertTo-Json
Test-Endpoint -Name "PUT /teachers/profile" -Method PUT -Uri "/api/v1/teachers/profile" -Body $updateTeacher -Headers $tAuth

Test-Endpoint -Name "GET /teachers/dashboard" -Method GET -Uri "/api/v1/teachers/dashboard" -Headers $tAuth

# Get subjects and levels for offering creation
$subjectsResp = docker exec educonnect-postgres psql -U educonnect -d educonnect -t -A -c "SELECT id FROM subjects LIMIT 1;" 2>&1
$levelsResp = docker exec educonnect-postgres psql -U educonnect -d educonnect -t -A -c "SELECT id FROM levels LIMIT 1;" 2>&1
$subjectId = ($subjectsResp | Out-String).Trim()
$levelId = ($levelsResp | Out-String).Trim()

# Offerings CRUD
$offeringBody = @{
    subject_id = $subjectId
    level_id = $levelId
    session_type = "one_on_one"
    price_per_hour = 2000
    max_students = 1
    free_trial_enabled = $true
    free_trial_duration = 15
} | ConvertTo-Json

$offeringResp = Test-Endpoint -Name "POST /teachers/offerings" -Method POST -Uri "/api/v1/teachers/offerings" -Body $offeringBody -Headers $tAuth -ExpectedStatus @(201)
$offeringId = if ($offeringResp) { $offeringResp.data.id } else { "none" }

Test-Endpoint -Name "GET /teachers/offerings" -Method GET -Uri "/api/v1/teachers/offerings" -Headers $tAuth

if ($offeringId -ne "none") {
    $updateOff = @{ price_per_hour = 2500; is_active = $true } | ConvertTo-Json
    Test-Endpoint -Name "PUT /teachers/offerings/:id" -Method PUT -Uri "/api/v1/teachers/offerings/$offeringId" -Body $updateOff -Headers $tAuth
    Test-Endpoint -Name "DELETE /teachers/offerings/:id" -Method DELETE -Uri "/api/v1/teachers/offerings/$offeringId" -Headers $tAuth
}

# Availability
$availBody = @{
    slots = @(
        @{ day_of_week = 1; start_time = "08:00"; end_time = "12:00" }
        @{ day_of_week = 3; start_time = "14:00"; end_time = "18:00" }
    )
} | ConvertTo-Json -Depth 3

Test-Endpoint -Name "PUT /teachers/availability" -Method PUT -Uri "/api/v1/teachers/availability" -Body $availBody -Headers $tAuth
Test-Endpoint -Name "GET /teachers/:id/availability" -Method GET -Uri "/api/v1/teachers/$teacherId/availability" -Headers $tAuth

# Earnings
Test-Endpoint -Name "GET /teachers/earnings" -Method GET -Uri "/api/v1/teachers/earnings" -Headers $tAuth

# ─── 5. Student ─────────────────────────────────────────────
Write-Host "`n📌 Student Module" -ForegroundColor Yellow

Test-Endpoint -Name "GET /students/dashboard" -Method GET -Uri "/api/v1/students/dashboard" -Headers $sAuth
Test-Endpoint -Name "GET /students/progress" -Method GET -Uri "/api/v1/students/progress" -Headers $sAuth
Test-Endpoint -Name "GET /students/enrollments" -Method GET -Uri "/api/v1/students/enrollments" -Headers $sAuth

# ─── 6. Parent ──────────────────────────────────────────────
Write-Host "`n📌 Parent Module" -ForegroundColor Yellow

Test-Endpoint -Name "GET /parents/dashboard" -Method GET -Uri "/api/v1/parents/dashboard" -Headers $pAuth
Test-Endpoint -Name "GET /parents/children" -Method GET -Uri "/api/v1/parents/children" -Headers $pAuth

$childBody = @{
    first_name = "Amine"
    last_name = "Bouzid"
    level_code = "3AM"
    school = "CEM El-Feth"
} | ConvertTo-Json

$childResp = Test-Endpoint -Name "POST /parents/children" -Method POST -Uri "/api/v1/parents/children" -Body $childBody -Headers $pAuth -ExpectedStatus @(201)
$childId = if ($childResp) { $childResp.data.id } else { "none" }

if ($childId -ne "none") {
    Test-Endpoint -Name "GET /parents/children/:childId/progress" -Method GET -Uri "/api/v1/parents/children/$childId/progress" -Headers $pAuth

    $updateChildBody = @{
        first_name = "Amine-Updated"
        school = "Lycée El-Mokrani"
    } | ConvertTo-Json
    Test-Endpoint -Name "PUT /parents/children/:childId" -Method PUT -Uri "/api/v1/parents/children/$childId" -Body $updateChildBody -Headers $pAuth

    Test-Endpoint -Name "DELETE /parents/children/:childId" -Method DELETE -Uri "/api/v1/parents/children/$childId" -Headers $pAuth
}

# ─── 7. Session ─────────────────────────────────────────────
Write-Host "`n📌 Session Module" -ForegroundColor Yellow

$futureStart = (Get-Date).AddDays(3).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$futureEnd   = (Get-Date).AddDays(3).AddHours(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$sessionBody = @{
    title = "Smoke Test Session - Maths 3AM"
    description = "Testing session creation"
    session_type = "one_on_one"
    start_time = $futureStart
    end_time = $futureEnd
    max_students = 1
    price = 2000
} | ConvertTo-Json

$sessionResp = Test-Endpoint -Name "POST /sessions (teacher)" -Method POST -Uri "/api/v1/sessions" -Body $sessionBody -Headers $tAuth -ExpectedStatus @(201)
$sessionId = if ($sessionResp) { $sessionResp.data.id } else { "none" }

Test-Endpoint -Name "GET /sessions" -Method GET -Uri "/api/v1/sessions" -Headers $tAuth

if ($sessionId -ne "none") {
    Test-Endpoint -Name "GET /sessions/:id" -Method GET -Uri "/api/v1/sessions/$sessionId" -Headers $tAuth

    $reschedStart = (Get-Date).AddDays(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $reschedEnd   = (Get-Date).AddDays(5).AddHours(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $reschedBody = @{ start_time = $reschedStart; end_time = $reschedEnd } | ConvertTo-Json
    Test-Endpoint -Name "PUT /sessions/:id/reschedule" -Method PUT -Uri "/api/v1/sessions/$sessionId/reschedule" -Body $reschedBody -Headers $tAuth

    $cancelBody = @{ reason = "Smoke test cancellation — not a real session" } | ConvertTo-Json
    Test-Endpoint -Name "POST /sessions/:id/cancel" -Method POST -Uri "/api/v1/sessions/$sessionId/cancel" -Body $cancelBody -Headers $tAuth

    # Join needs a separate session (join sets status to 'live', blocking reschedule/cancel)
    $session2Body = @{
        title = "Smoke Test Session 2 - Join"
        description = "Testing join"
        session_type = "one_on_one"
        start_time = $futureStart
        end_time = $futureEnd
        max_students = 1
        price = 2000
    } | ConvertTo-Json
    $session2Resp = Test-Endpoint -Name "POST /sessions (for join)" -Method POST -Uri "/api/v1/sessions" -Body $session2Body -Headers $tAuth -ExpectedStatus @(201)
    $session2Id = if ($session2Resp) { $session2Resp.data.id } else { "none" }
    if ($session2Id -ne "none") {
        Test-Endpoint -Name "POST /sessions/:id/join" -Method POST -Uri "/api/v1/sessions/$session2Id/join" -Headers $sAuth
    }
}

# ─── 8. Course Module ────────────────────────────────────────
Write-Host "`n📌 Course Module" -ForegroundColor Yellow

$courseBody = @{
    title = "Maths 3AM — Smoke Test Course"
    description = "Algèbre et géométrie pour le niveau 3AM"
    subject_id = $subjectId
    level_id = $levelId
    price = 5000
    is_published = $true
} | ConvertTo-Json

$courseResp = Test-Endpoint -Name "POST /courses" -Method POST -Uri "/api/v1/courses" -Body $courseBody -Headers $tAuth -ExpectedStatus @(201)
$courseId = if ($courseResp) { $courseResp.data.id } else { "none" }

Test-Endpoint -Name "GET /courses" -Method GET -Uri "/api/v1/courses" -Headers $tAuth

if ($courseId -ne "none") {
    Test-Endpoint -Name "GET /courses/:id" -Method GET -Uri "/api/v1/courses/$courseId" -Headers $tAuth

    $updateCourse = @{ title = "Maths 3AM — Updated Title" } | ConvertTo-Json
    Test-Endpoint -Name "PUT /courses/:id" -Method PUT -Uri "/api/v1/courses/$courseId" -Body $updateCourse -Headers $tAuth

    # Chapter
    $chapterBody = @{ title = "Chapitre 1 — Les Nombres Rationnels"; order = 1 } | ConvertTo-Json
    $chapterResp = Test-Endpoint -Name "POST /courses/:id/chapters" -Method POST -Uri "/api/v1/courses/$courseId/chapters" -Body $chapterBody -Headers $tAuth -ExpectedStatus @(201)
    $chapterId = if ($chapterResp) { $chapterResp.data.id } else { "none" }

    if ($chapterId -ne "none") {
        # Lesson
        $lessonBody = @{ title = "Leçon 1 — Introduction"; description = "Intro to rational numbers"; order = 1; is_preview = $true } | ConvertTo-Json
        $lessonResp = Test-Endpoint -Name "POST /courses/:id/chapters/:chId/lessons" -Method POST -Uri "/api/v1/courses/$courseId/chapters/$chapterId/lessons" -Body $lessonBody -Headers $tAuth -ExpectedStatus @(201)
    }

    # Enroll student
    Test-Endpoint -Name "POST /courses/:id/enroll (student)" -Method POST -Uri "/api/v1/courses/$courseId/enroll" -Headers $sAuth -ExpectedStatus @(201)

    # Will delete later in cleanup
}

# ─── 9. Homework Module ─────────────────────────────────────
Write-Host "`n📌 Homework Module" -ForegroundColor Yellow

$hwBody = @{
    title = "Exercice — Les Nombres Rationnels"
    description = "Résolvez les problèmes suivants"
    instructions = "Montrez votre travail"
    subject_id = $subjectId
    level_id = $levelId
    allow_late = $true
    late_penalty_percent = 10
} | ConvertTo-Json

$hwResp = Test-Endpoint -Name "POST /homework" -Method POST -Uri "/api/v1/homework" -Body $hwBody -Headers $tAuth -ExpectedStatus @(201)
$hwId = if ($hwResp) { $hwResp.data.id } else { "none" }

Test-Endpoint -Name "GET /homework" -Method GET -Uri "/api/v1/homework" -Headers $tAuth

if ($hwId -ne "none") {
    Test-Endpoint -Name "GET /homework/:id" -Method GET -Uri "/api/v1/homework/$hwId" -Headers $tAuth

    # Student submits
    $submitBody = @{ text_content = "Voici mes réponses: 1) 3/4 + 1/2 = 5/4"; file_urls = @() } | ConvertTo-Json
    $submitResp = Test-Endpoint -Name "POST /homework/:id/submit" -Method POST -Uri "/api/v1/homework/$hwId/submit" -Body $submitBody -Headers $sAuth -ExpectedStatus @(201)
    $submissionId = if ($submitResp) { $submitResp.data.id } else { "none" }

    if ($submissionId -ne "none") {
        # Teacher grades
        $gradeBody = @{ grade = 16.5; max_grade = 20; feedback = "Bon travail, quelques erreurs mineures" } | ConvertTo-Json
        Test-Endpoint -Name "PUT /homework/submissions/:id/grade" -Method PUT -Uri "/api/v1/homework/submissions/$submissionId/grade" -Body $gradeBody -Headers $tAuth
    }
}

# ─── 10. Quiz Module ────────────────────────────────────────
Write-Host "`n📌 Quiz Module" -ForegroundColor Yellow

$quizBody = @{
    title = "Quiz — Les Nombres Rationnels"
    description = "Testez vos connaissances"
    subject_id = $subjectId
    level_id = $levelId
    time_limit_minutes = 30
    max_attempts = 2
    show_answers_after = $true
    questions = @(
        @{
            type = "multiple_choice_single"
            question = "Quel est le résultat de 1/2 + 1/3?"
            options = @("2/5", "5/6", "1/6", "3/5")
            correct_answer = "5/6"
        }
        @{
            type = "true_false"
            question = "0.333... est un nombre rationnel"
            correct_answer = "true"
        }
    )
} | ConvertTo-Json -Depth 4

$quizResp = Test-Endpoint -Name "POST /quizzes" -Method POST -Uri "/api/v1/quizzes" -Body $quizBody -Headers $tAuth -ExpectedStatus @(201)
$quizId = if ($quizResp) { $quizResp.data.id } else { "none" }

Test-Endpoint -Name "GET /quizzes" -Method GET -Uri "/api/v1/quizzes" -Headers $tAuth

if ($quizId -ne "none") {
    Test-Endpoint -Name "GET /quizzes/:id" -Method GET -Uri "/api/v1/quizzes/$quizId" -Headers $tAuth

    # Student attempt
    $attemptBody = @{
        answers = @(
            @{ question_index = 0; answer = "5/6" }
            @{ question_index = 1; answer = "true" }
        )
    } | ConvertTo-Json -Depth 3

    Test-Endpoint -Name "POST /quizzes/:id/attempt" -Method POST -Uri "/api/v1/quizzes/$quizId/attempt" -Body $attemptBody -Headers $sAuth -ExpectedStatus @(201)

    # Results
    Test-Endpoint -Name "GET /quizzes/:id/results (teacher)" -Method GET -Uri "/api/v1/quizzes/$quizId/results" -Headers $tAuth
}

# ─── 11. Search ──────────────────────────────────────────────
Write-Host "`n📌 Search Module" -ForegroundColor Yellow

Test-Endpoint -Name "GET /search/teachers?q=karim" -Method GET -Uri "/api/v1/search/teachers?q=karim" -Headers $tAuth
Test-Endpoint -Name "GET /search/courses?q=math" -Method GET -Uri "/api/v1/search/courses?q=math" -Headers $tAuth

# ─── 12. Review Module ──────────────────────────────────────
Write-Host "`n📌 Review Module" -ForegroundColor Yellow

# To review, we need a completed session with the student as participant.
# End session2 first (it was joined, so it should be "live")
if ($session2Id -ne "none" -and $session2Id) {
    # End the session to mark it completed
    Test-Endpoint -Name "POST /sessions/:id/end (for review)" -Method POST -Uri "/api/v1/sessions/$session2Id/end" -Headers $tAuth

    # Now student reviews the teacher
    $reviewBody = @{
        session_id = $session2Id
        teacher_id = $teacherId
        overall_rating = 5
        teaching_quality = 5
        communication = 4
        punctuality = 5
        review_text = "Excellent professeur, très patient!"
    } | ConvertTo-Json

    $reviewResp = Test-Endpoint -Name "POST /reviews" -Method POST -Uri "/api/v1/reviews" -Body $reviewBody -Headers $sAuth -ExpectedStatus @(201)
    $reviewId = if ($reviewResp) { $reviewResp.data.id } else { "none" }

    # Get teacher reviews
    Test-Endpoint -Name "GET /reviews/teacher/:id" -Method GET -Uri "/api/v1/reviews/teacher/$teacherId" -Headers $tAuth

    # Teacher responds
    if ($reviewId -ne "none") {
        $respondBody = @{ response = "Merci beaucoup pour votre avis!" } | ConvertTo-Json
        Test-Endpoint -Name "POST /reviews/:id/respond" -Method POST -Uri "/api/v1/reviews/$reviewId/respond" -Body $respondBody -Headers $tAuth
    }
}

# ─── 13. Notification Module ────────────────────────────────
Write-Host "`n📌 Notification Module" -ForegroundColor Yellow

Test-Endpoint -Name "GET /notifications" -Method GET -Uri "/api/v1/notifications" -Headers $tAuth

# Update preferences
$prefsBody = @{
    session_reminders = $true
    homework_alerts = $true
    payment_alerts = $false
    marketing = $false
} | ConvertTo-Json

Test-Endpoint -Name "PUT /notifications/preferences" -Method PUT -Uri "/api/v1/notifications/preferences" -Body $prefsBody -Headers $tAuth

# Insert a test notification directly and test mark-read
$notifRaw = docker exec educonnect-postgres psql -U educonnect -d educonnect -t -A -c "INSERT INTO notifications (user_id, type, title, body) VALUES ('$teacherId', 'test', 'Smoke Test', 'Test notification body') RETURNING id;" 2>$null
$notifId = ($notifRaw | Out-String).Trim()
# Ensure we have a valid UUID (36 chars with dashes)
if ($notifId -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
    Test-Endpoint -Name "PUT /notifications/:id/read" -Method PUT -Uri "/api/v1/notifications/$notifId/read" -Headers $tAuth
} else {
    Write-Host "  ⚠ Skipping notification mark-read — could not extract notification ID" -ForegroundColor Yellow
}

# ─── 14. Payment Module ─────────────────────────────────────
Write-Host "`n📌 Payment Module" -ForegroundColor Yellow

$studentId = $studentResp.data.user.id

$payBody = @{
    payee_id = $teacherId
    session_id = $session2Id
    amount = 2000
    payment_method = "ccp_baridimob"
    description = "Payment for smoke test session"
} | ConvertTo-Json

$payResp = Test-Endpoint -Name "POST /payments/initiate" -Method POST -Uri "/api/v1/payments/initiate" -Body $payBody -Headers $sAuth -ExpectedStatus @(201)
$txnId = if ($payResp) { $payResp.data.id } else { "none" }

if ($txnId -ne "none") {
    # Confirm payment
    $confirmBody = @{
        transaction_id = $txnId
        provider_reference = "SMOKE-TEST-REF-001"
    } | ConvertTo-Json
    Test-Endpoint -Name "POST /payments/confirm" -Method POST -Uri "/api/v1/payments/confirm" -Body $confirmBody -Headers $sAuth
}

# Payment history
Test-Endpoint -Name "GET /payments/history" -Method GET -Uri "/api/v1/payments/history" -Headers $sAuth

# Refund (on the confirmed transaction)
if ($txnId -ne "none") {
    $refundBody = @{
        transaction_id = $txnId
        amount = 2000
        reason = "Smoke test refund"
    } | ConvertTo-Json
    Test-Endpoint -Name "POST /payments/refund" -Method POST -Uri "/api/v1/payments/refund" -Body $refundBody -Headers $sAuth
}

# ─── 15. Subscription Module ────────────────────────────────
Write-Host "`n📌 Subscription Module" -ForegroundColor Yellow

$subBody = @{
    teacher_id = $teacherId
    plan_type = "monthly_4"
    sessions_per_month = 4
    price = 8000
    start_date = (Get-Date).ToString("yyyy-MM-dd")
    end_date = (Get-Date).AddMonths(1).ToString("yyyy-MM-dd")
    auto_renew = $true
} | ConvertTo-Json

$subResp = Test-Endpoint -Name "POST /subscriptions" -Method POST -Uri "/api/v1/subscriptions" -Body $subBody -Headers $sAuth -ExpectedStatus @(201)
$subId = if ($subResp) { $subResp.data.id } else { "none" }

Test-Endpoint -Name "GET /subscriptions" -Method GET -Uri "/api/v1/subscriptions" -Headers $sAuth

if ($subId -ne "none") {
    Test-Endpoint -Name "DELETE /subscriptions/:id" -Method DELETE -Uri "/api/v1/subscriptions/$subId" -Headers $sAuth
}

# ─── 16. Admin Module ───────────────────────────────────────
Write-Host "`n📌 Admin Module" -ForegroundColor Yellow

# Create an admin user directly in the DB and get a token
$adminPwHash = docker exec educonnect-postgres psql -U educonnect -d educonnect -t -A -c "SELECT crypt('AdminPass123!', gen_salt('bf'));" 2>&1
$adminPwHash = ($adminPwHash | Out-String).Trim()

docker exec educonnect-postgres psql -U educonnect -d educonnect -c "INSERT INTO users (email, phone, password_hash, role, first_name, last_name, wilaya, is_active, is_email_verified) VALUES ('smoke.admin@test.dz', '+213550100099', '$adminPwHash', 'admin', 'Admin', 'Smoke', 'Alger', true, true) ON CONFLICT (email) DO NOTHING;" 2>&1 | Out-Null

$adminLoginBody = @{
    email = "smoke.admin@test.dz"
    password = "AdminPass123!"
} | ConvertTo-Json

$adminLoginResp = Test-Endpoint -Name "POST /auth/login (admin)" -Method POST -Uri "/api/v1/auth/login" -Body $adminLoginBody
$adminToken = if ($adminLoginResp) { $adminLoginResp.data.access_token } else { "" }
$aAuth = @{ Authorization = "Bearer $adminToken" }

if ($adminToken -ne "") {
    # Users
    Test-Endpoint -Name "GET /admin/users" -Method GET -Uri "/api/v1/admin/users" -Headers $aAuth
    Test-Endpoint -Name "GET /admin/users/:id" -Method GET -Uri "/api/v1/admin/users/$teacherId" -Headers $aAuth

    # Verifications
    Test-Endpoint -Name "GET /admin/verifications" -Method GET -Uri "/api/v1/admin/verifications" -Headers $aAuth

    # Get the teacher's verification ID
    $verifyIdRaw = docker exec educonnect-postgres psql -U educonnect -d educonnect -t -A -c "SELECT id FROM teacher_profiles WHERE user_id = '$teacherId' LIMIT 1;" 2>&1
    $verifyId = ($verifyIdRaw | Out-String).Trim()

    if ($verifyId -and $verifyId -ne "") {
        Test-Endpoint -Name "PUT /admin/verifications/:id/approve" -Method PUT -Uri "/api/v1/admin/verifications/$verifyId/approve" -Headers $aAuth
    }

    # Transactions
    Test-Endpoint -Name "GET /admin/transactions" -Method GET -Uri "/api/v1/admin/transactions" -Headers $aAuth

    # Disputes (list — likely empty)
    Test-Endpoint -Name "GET /admin/disputes" -Method GET -Uri "/api/v1/admin/disputes" -Headers $aAuth

    # Analytics
    Test-Endpoint -Name "GET /admin/analytics/overview" -Method GET -Uri "/api/v1/admin/analytics/overview" -Headers $aAuth
    Test-Endpoint -Name "GET /admin/analytics/revenue" -Method GET -Uri "/api/v1/admin/analytics/revenue" -Headers $aAuth

    # Config — Subjects
    $subjectsBody = @{
        subjects = @(
            @{ name = "Physique"; category = "sciences" }
            @{ name = "Histoire"; category = "humanities" }
        )
    } | ConvertTo-Json -Depth 3

    Test-Endpoint -Name "PUT /admin/config/subjects" -Method PUT -Uri "/api/v1/admin/config/subjects" -Body $subjectsBody -Headers $aAuth

    # Config — Levels
    $levelsBody = @{
        levels = @(
            @{ name = "4AP"; code = "4ap"; cycle = "primaire"; order = 4 }
            @{ name = "4AM"; code = "4am"; cycle = "cem"; order = 4 }
        )
    } | ConvertTo-Json -Depth 3

    Test-Endpoint -Name "PUT /admin/config/levels" -Method PUT -Uri "/api/v1/admin/config/levels" -Body $levelsBody -Headers $aAuth

    # Suspend a test user (we'll use the student since cleanup will delete them anyway)
    Test-Endpoint -Name "PUT /admin/users/:id/suspend" -Method PUT -Uri "/api/v1/admin/users/$studentId/suspend" -Headers $aAuth
}

# ─── 17. Stubs — verify NOT_IMPLEMENTED ─────────────────────
Write-Host "`n📌 Stubs (should return 501)" -ForegroundColor Yellow

Test-Endpoint -Name "POST /auth/forgot-password (stub)" -Method POST -Uri "/api/v1/auth/forgot-password" -Body '{"email":"a@b.com"}' -ExpectedStatus @(501)

# ─── 18. Cleanup — Deactivate test accounts ─────────────────
Write-Host "`n📌 Cleanup" -ForegroundColor Yellow

if ($courseId -ne "none" -and $courseId) {
    Test-Endpoint -Name "DELETE /courses/:id" -Method DELETE -Uri "/api/v1/courses/$courseId" -Headers $tAuth
}

Test-Endpoint -Name "DELETE /users/me (teacher)" -Method DELETE -Uri "/api/v1/users/me" -Headers $tAuth
Test-Endpoint -Name "DELETE /users/me (parent)" -Method DELETE -Uri "/api/v1/users/me" -Headers $pAuth
Test-Endpoint -Name "DELETE /users/me (student)" -Method DELETE -Uri "/api/v1/users/me" -Headers $sAuth

# Clean up admin user
docker exec educonnect-postgres psql -U educonnect -d educonnect -c "DELETE FROM users WHERE email = 'smoke.admin@test.dz';" 2>&1 | Out-Null

# ─── Results ─────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESULTS: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

if ($errors.Count -gt 0) {
    Write-Host "`n  Failures:" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "    • $e" -ForegroundColor Red
    }
}

Write-Host ""
exit $fail
