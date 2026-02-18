package integration_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"educonnect/internal/booking"
	"educonnect/internal/config"
	"educonnect/internal/payment"
	"educonnect/internal/sessionseries"
	teacherpkg "educonnect/internal/teacher"
	"educonnect/internal/wallet"
	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
)

// ═══════════════════════════════════════════════════════════════
// Global Test Setup
// ═══════════════════════════════════════════════════════════════

var (
	testDB         *database.Postgres
	bookingService *booking.Service
	seriesService  *sessionseries.Service
	teacherService *teacherpkg.Service
	paymentService *payment.Service
	walletService  *wallet.Service
)

// TestUser represents a user created for testing
type TestUser struct {
	ID        uuid.UUID
	Email     string
	Role      string
	FirstName string
	LastName  string
}

// TestOffering represents an offering created for testing
type TestOffering struct {
	ID        uuid.UUID
	TeacherID uuid.UUID
	SubjectID uuid.UUID
	LevelID   uuid.UUID
}

func TestMain(m *testing.M) {
	// Setup test database connection
	cfg := config.DatabaseConfig{
		Host:     getEnvOrDefault("DB_HOST", "localhost"),
		Port:     getEnvOrDefault("DB_PORT", "5433"),
		User:     getEnvOrDefault("DB_USER", "educonnect"),
		Password: getEnvOrDefault("DB_PASSWORD", "educonnect"),
		DBName:   getEnvOrDefault("DB_NAME", "educonnect"),
		SSLMode:  "disable",
	}

	var err error
	testDB, err = database.NewPostgres(cfg)
	if err != nil {
		fmt.Printf("Failed to connect to test database: %v\n", err)
		os.Exit(1)
	}
	defer testDB.Close()

	// Initialize services
	bookingService = booking.NewService(testDB, nil) // No notification service for tests
	walletService = wallet.NewService(testDB)
	seriesService = sessionseries.NewService(testDB, nil, walletService) // No LiveKit for tests
	teacherService = teacherpkg.NewService(testDB, nil)                  // No Meilisearch for tests
	paymentService = payment.NewService(testDB)

	// Run tests
	code := m.Run()
	os.Exit(code)
}

func getEnvOrDefault(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

// ═══════════════════════════════════════════════════════════════
// Database Helpers
// ═══════════════════════════════════════════════════════════════

func createTestUser(t *testing.T, ctx context.Context, role, firstName, lastName string) TestUser {
	t.Helper()

	id := uuid.New()
	email := fmt.Sprintf("%s_%s@test.com", firstName, id.String()[:8])
	hash, _ := bcrypt.GenerateFromPassword([]byte("test123456"), 12)

	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, role, first_name, last_name, wilaya, language)
		VALUES ($1, $2, $3, $4, $5, $6, 'Alger', 'fr')
	`, id, email, string(hash), role, firstName, lastName)
	require.NoError(t, err)

	return TestUser{ID: id, Email: email, Role: role, FirstName: firstName, LastName: lastName}
}

func createTeacherWithProfile(t *testing.T, ctx context.Context, firstName, lastName string) TestUser {
	t.Helper()
	user := createTestUser(t, ctx, "teacher", firstName, lastName)

	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO teacher_profiles (user_id, bio, verification_status)
		VALUES ($1, 'Test teacher bio', 'verified')
	`, user.ID)
	require.NoError(t, err)

	return user
}

func createStudentWithProfile(t *testing.T, ctx context.Context, firstName, lastName string, parentID *uuid.UUID) TestUser {
	t.Helper()
	user := createTestUser(t, ctx, "student", firstName, lastName)

	var levelID uuid.UUID
	err := testDB.Pool.QueryRow(ctx, `SELECT id FROM levels LIMIT 1`).Scan(&levelID)
	require.NoError(t, err)

	_, err = testDB.Pool.Exec(ctx, `
		INSERT INTO student_profiles (user_id, level_id, parent_id, is_independent)
		VALUES ($1, $2, $3, $4)
	`, user.ID, levelID, parentID, parentID == nil)
	require.NoError(t, err)

	return user
}

func createParentWithProfile(t *testing.T, ctx context.Context, firstName, lastName string) TestUser {
	t.Helper()
	user := createTestUser(t, ctx, "parent", firstName, lastName)

	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO parent_profiles (user_id) VALUES ($1)
	`, user.ID)
	require.NoError(t, err)

	return user
}

func createTeacherAvailability(t *testing.T, ctx context.Context, teacherID uuid.UUID, dayOfWeek int, startTime, endTime string) {
	t.Helper()
	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO availability_slots (teacher_id, day_of_week, start_time, end_time)
		VALUES ($1, $2, $3::time, $4::time)
		ON CONFLICT DO NOTHING
	`, teacherID, dayOfWeek, startTime, endTime)
	require.NoError(t, err)
}

func createOffering(t *testing.T, ctx context.Context, teacherID uuid.UUID) TestOffering {
	t.Helper()

	var subjectID, levelID uuid.UUID
	err := testDB.Pool.QueryRow(ctx, `SELECT id FROM subjects LIMIT 1`).Scan(&subjectID)
	require.NoError(t, err)
	err = testDB.Pool.QueryRow(ctx, `SELECT id FROM levels LIMIT 1`).Scan(&levelID)
	require.NoError(t, err)

	offeringID := uuid.New()
	_, err = testDB.Pool.Exec(ctx, `
		INSERT INTO offerings (id, teacher_id, subject_id, level_id, session_type, price_per_hour, max_students, is_active)
		VALUES ($1, $2, $3, $4, 'one_on_one', 2000, 1, true)
	`, offeringID, teacherID, subjectID, levelID)
	require.NoError(t, err)

	return TestOffering{ID: offeringID, TeacherID: teacherID, SubjectID: subjectID, LevelID: levelID}
}

func cleanupTestUser(t *testing.T, ctx context.Context, userID uuid.UUID) {
	t.Helper()
	// Delete in reverse order of foreign keys
	testDB.Pool.Exec(ctx, `DELETE FROM wallet_transactions WHERE wallet_id IN (SELECT id FROM teacher_wallets WHERE teacher_id = $1)`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM teacher_wallets WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM platform_fees WHERE series_id IN (SELECT id FROM session_series WHERE teacher_id = $1)`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM session_participants WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM session_participants WHERE student_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM session_enrollments WHERE student_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM session_enrollments WHERE series_id IN (SELECT id FROM session_series WHERE teacher_id = $1)`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM sessions WHERE series_id IN (SELECT id FROM session_series WHERE teacher_id = $1)`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM sessions WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM session_series WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM booking_messages WHERE booking_id IN (SELECT id FROM booking_requests WHERE student_id = $1 OR teacher_id = $1)`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM booking_requests WHERE student_id = $1 OR teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM booking_requests WHERE booked_by_parent_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM transactions WHERE payer_id = $1 OR payee_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM subscriptions WHERE student_id = $1 OR teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM offerings WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM teacher_profiles WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM student_profiles WHERE user_id = $1 OR parent_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM parent_profiles WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, userID)
}

// fundTeacherWallet creates a wallet for the teacher, buys the Premium credit package
// (5000 + 400 bonus = 5400 DZD), and approves it immediately so the teacher has
// enough balance for star deductions in enrollment acceptance tests.
func fundTeacherWallet(t *testing.T, ctx context.Context, teacherID uuid.UUID) {
	t.Helper()
	admin := createTestUser(t, ctx, "admin", "WalletFund", "Admin")
	defer cleanupTestUser(t, ctx, admin.ID)

	pkgs, err := walletService.ListPackages(ctx)
	require.NoError(t, err)
	require.NotEmpty(t, pkgs)

	// Pick the largest package (Premium: 5000 + 400 bonus = 5400)
	largest := pkgs[len(pkgs)-1]
	tx, err := walletService.BuyCredits(ctx, teacherID.String(), wallet.BuyCreditsRequest{
		PackageID:     largest.ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   fmt.Sprintf("FUND-%s", teacherID.String()[:8]),
	})
	require.NoError(t, err)

	_, err = walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "test funding")
	require.NoError(t, err)
}

func getNextWeekday(weekday time.Weekday) time.Time {
	now := time.Now()
	daysUntil := int(weekday) - int(now.Weekday())
	if daysUntil <= 0 {
		daysUntil += 7
	}
	return now.AddDate(0, 0, daysUntil)
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 1: Teacher Availability Management
// ═══════════════════════════════════════════════════════════════

func TestTeacherAvailability(t *testing.T) {
	ctx := context.Background()

	// Setup
	teacher := createTeacherWithProfile(t, ctx, "Avail", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	// ─── Test: Set availability ─────────────────────────────────
	t.Run("SetAvailability", func(t *testing.T) {
		req := teacherpkg.SetAvailabilityRequest{
			Slots: []teacherpkg.AvailabilitySlotInput{
				{DayOfWeek: 1, StartTime: "09:00", EndTime: "12:00"}, // Monday AM
				{DayOfWeek: 1, StartTime: "14:00", EndTime: "18:00"}, // Monday PM
				{DayOfWeek: 3, StartTime: "10:00", EndTime: "16:00"}, // Wednesday
				{DayOfWeek: 5, StartTime: "08:00", EndTime: "20:00"}, // Friday all day
			},
		}
		slots, err := teacherService.SetAvailability(ctx, teacher.ID.String(), req)
		require.NoError(t, err)
		assert.Len(t, slots, 4)
		t.Logf("✓ Set %d availability slots", len(slots))
	})

	// ─── Test: Get availability ─────────────────────────────────
	t.Run("GetAvailability", func(t *testing.T) {
		slots, err := teacherService.GetAvailability(ctx, teacher.ID.String())
		require.NoError(t, err)
		assert.Len(t, slots, 4)

		// Verify slots
		days := make(map[int]bool)
		for _, s := range slots {
			days[s.DayOfWeek] = true
		}
		assert.True(t, days[1], "Should have Monday slots")
		assert.True(t, days[3], "Should have Wednesday slot")
		assert.True(t, days[5], "Should have Friday slot")

		t.Logf("✓ Retrieved %d availability slots", len(slots))
	})

	// ─── Test: Update availability (replace) ────────────────────
	t.Run("UpdateAvailability", func(t *testing.T) {
		// Set new availability (replaces old)
		req := teacherpkg.SetAvailabilityRequest{
			Slots: []teacherpkg.AvailabilitySlotInput{
				{DayOfWeek: 2, StartTime: "09:00", EndTime: "17:00"}, // Tuesday only
			},
		}
		slots, err := teacherService.SetAvailability(ctx, teacher.ID.String(), req)
		require.NoError(t, err)
		assert.Len(t, slots, 1)
		assert.Equal(t, 2, slots[0].DayOfWeek)

		t.Log("✓ Updated availability (old slots replaced)")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 2: Teacher Offerings
// ═══════════════════════════════════════════════════════════════

func TestTeacherOfferings(t *testing.T) {
	ctx := context.Background()

	// Setup
	teacherUser := createTeacherWithProfile(t, ctx, "Offering", "Teacher")
	defer cleanupTestUser(t, ctx, teacherUser.ID)

	var subjectID, levelID uuid.UUID
	testDB.Pool.QueryRow(ctx, `SELECT id FROM subjects WHERE name_fr LIKE '%Math%' LIMIT 1`).Scan(&subjectID)
	if subjectID == uuid.Nil {
		testDB.Pool.QueryRow(ctx, `SELECT id FROM subjects LIMIT 1`).Scan(&subjectID)
	}
	testDB.Pool.QueryRow(ctx, `SELECT id FROM levels LIMIT 1`).Scan(&levelID)

	var createdOfferingID uuid.UUID

	// ─── Test: Create offering ──────────────────────────────────
	t.Run("CreateOffering", func(t *testing.T) {
		req := teacherpkg.CreateOfferingRequest{
			SubjectID:         subjectID,
			LevelID:           levelID,
			SessionType:       "one_on_one",
			PricePerHour:      2500,
			MaxStudents:       1,
			FreeTrialEnabled:  true,
			FreeTrialDuration: 30,
		}
		offering, err := teacherService.CreateOffering(ctx, teacherUser.ID.String(), req)
		require.NoError(t, err)
		require.NotNil(t, offering)

		assert.Equal(t, teacherUser.ID, offering.TeacherID)
		assert.Equal(t, subjectID, offering.SubjectID)
		assert.Equal(t, 2500.0, offering.PricePerHour)
		assert.True(t, offering.FreeTrialEnabled)
		assert.True(t, offering.IsActive)

		createdOfferingID = offering.ID
		t.Logf("✓ Created offering %s", offering.ID)
	})

	// ─── Test: List offerings ───────────────────────────────────
	t.Run("ListOfferings", func(t *testing.T) {
		offerings, err := teacherService.ListOfferings(ctx, teacherUser.ID.String())
		require.NoError(t, err)
		assert.GreaterOrEqual(t, len(offerings), 1)

		found := false
		for _, o := range offerings {
			if o.ID == createdOfferingID {
				found = true
				break
			}
		}
		assert.True(t, found, "Should find created offering in list")

		t.Logf("✓ Listed %d offerings", len(offerings))
	})

	// ─── Test: Update offering ──────────────────────────────────
	t.Run("UpdateOffering", func(t *testing.T) {
		newPrice := 3000.0
		req := teacherpkg.UpdateOfferingRequest{
			PricePerHour: &newPrice,
		}
		offering, err := teacherService.UpdateOffering(ctx, teacherUser.ID.String(), createdOfferingID.String(), req)
		require.NoError(t, err)
		assert.Equal(t, 3000.0, offering.PricePerHour)

		t.Log("✓ Updated offering price")
	})

	// ─── Test: Deactivate offering ──────────────────────────────
	t.Run("DeactivateOffering", func(t *testing.T) {
		err := teacherService.DeleteOffering(ctx, teacherUser.ID.String(), createdOfferingID.String())
		require.NoError(t, err)

		// Verify it's deactivated
		offerings, _ := teacherService.ListOfferings(ctx, teacherUser.ID.String())
		for _, o := range offerings {
			if o.ID == createdOfferingID {
				assert.False(t, o.IsActive)
			}
		}

		t.Log("✓ Deactivated offering")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 3: Session Series Full Workflow
// ═══════════════════════════════════════════════════════════════

func TestSessionSeriesFullWorkflow(t *testing.T) {
	ctx := context.Background()

	// ─── Setup: Create users ────────────────────────────────────
	teacher := createTeacherWithProfile(t, ctx, "Series", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	parent1 := createParentWithProfile(t, ctx, "Series", "Parent1")
	defer cleanupTestUser(t, ctx, parent1.ID)
	child1 := createStudentWithProfile(t, ctx, "Series", "Child1", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1.ID)

	parent2 := createParentWithProfile(t, ctx, "Series", "Parent2")
	defer cleanupTestUser(t, ctx, parent2.ID)
	child2 := createStudentWithProfile(t, ctx, "Series", "Child2", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2.ID)

	independentStudent := createStudentWithProfile(t, ctx, "Series", "IndStudent", nil)
	defer cleanupTestUser(t, ctx, independentStudent.ID)

	t.Logf("Users: Teacher=%s, Parent1=%s, Child1=%s, Parent2=%s, Child2=%s, IndStudent=%s",
		teacher.ID[:8], parent1.ID.String()[:8], child1.ID.String()[:8],
		parent2.ID.String()[:8], child2.ID.String()[:8], independentStudent.ID.String()[:8])

	// Fund teacher wallet so star deductions succeed on enrollment acceptance
	fundTeacherWallet(t, ctx, teacher.ID)

	var seriesID uuid.UUID

	// ─── Test: Create Series ────────────────────────────────────
	t.Run("CreateSeries", func(t *testing.T) {
		req := sessionseries.CreateSeriesRequest{
			Title:         "Cours de Mathématiques - 3AM",
			Description:   "Préparation au BEM",
			SessionType:   "group",
			DurationHours: 2,
			MinStudents:   2,
			MaxStudents:   10,
			PricePerHour:  1500,
		}
		series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), req)
		require.NoError(t, err)
		require.NotNil(t, series)

		seriesID = series.ID
		assert.Equal(t, "draft", series.Status)
		assert.Equal(t, "group", series.SessionType)
		assert.Equal(t, 10, series.MaxStudents)
		assert.Equal(t, 0, series.TotalSessions)

		t.Logf("✓ Created series %s in draft status", seriesID)
	})

	// ─── Test: Add Sessions to Series ───────────────────────────
	t.Run("AddSessions", func(t *testing.T) {
		nextMonday := getNextWeekday(time.Monday)
		sessions := []sessionseries.SessionDateInput{
			{StartTime: nextMonday.Add(9 * time.Hour).Format(time.RFC3339)},
			{StartTime: nextMonday.Add(7*24*time.Hour + 9*time.Hour).Format(time.RFC3339)},  // Week 2
			{StartTime: nextMonday.Add(14*24*time.Hour + 9*time.Hour).Format(time.RFC3339)}, // Week 3
			{StartTime: nextMonday.Add(21*24*time.Hour + 9*time.Hour).Format(time.RFC3339)}, // Week 4
		}

		req := sessionseries.AddSessionsRequest{Sessions: sessions}
		series, err := seriesService.AddSessions(ctx, seriesID.String(), teacher.ID.String(), req)
		require.NoError(t, err)

		assert.Equal(t, 4, series.TotalSessions)
		assert.Equal(t, "active", series.Status, "Should become active after adding sessions")
		assert.Len(t, series.Sessions, 4)

		t.Logf("✓ Added 4 sessions, series now active")
	})

	// ─── Test: Teacher invites students ─────────────────────────
	t.Run("TeacherInvitesStudents", func(t *testing.T) {
		req := sessionseries.InviteStudentsRequest{
			StudentIDs: []string{child1.ID.String(), child2.ID.String()},
		}
		enrollments, err := seriesService.InviteStudents(ctx, seriesID.String(), teacher.ID.String(), req)
		require.NoError(t, err)
		assert.Len(t, enrollments, 2)

		for _, e := range enrollments {
			assert.Equal(t, "invited", e.Status)
			assert.Equal(t, "teacher", e.InitiatedBy)
		}

		t.Logf("✓ Invited 2 students (child1, child2)")
	})

	// ─── Test: Student requests to join ─────────────────────────
	t.Run("StudentRequestsToJoin", func(t *testing.T) {
		enrollment, err := seriesService.RequestToJoin(ctx, seriesID.String(), independentStudent.ID.String())
		require.NoError(t, err)

		assert.Equal(t, "requested", enrollment.Status)
		assert.Equal(t, "student", enrollment.InitiatedBy)
		assert.Equal(t, independentStudent.ID, enrollment.StudentID)

		t.Logf("✓ Independent student requested to join")
	})

	// ─── Test: Student accepts invitation ───────────────────────
	var child1EnrollmentID uuid.UUID
	t.Run("StudentAcceptsInvitation", func(t *testing.T) {
		// Get child1's enrollment ID
		err := testDB.Pool.QueryRow(ctx,
			`SELECT id FROM session_enrollments WHERE series_id = $1 AND student_id = $2`,
			seriesID, child1.ID,
		).Scan(&child1EnrollmentID)
		require.NoError(t, err)

		enrollment, err := seriesService.AcceptInvitation(ctx, child1EnrollmentID.String(), child1.ID.String())
		require.NoError(t, err)
		assert.Equal(t, "accepted", enrollment.Status)
		assert.NotNil(t, enrollment.AcceptedAt)

		t.Logf("✓ Child1 accepted invitation")
	})

	// ─── Test: Parent accepts invitation on behalf of child ─────
	t.Run("ParentAcceptsForChild", func(t *testing.T) {
		// Get child2's enrollment ID
		var child2EnrollmentID uuid.UUID
		err := testDB.Pool.QueryRow(ctx,
			`SELECT id FROM session_enrollments WHERE series_id = $1 AND student_id = $2`,
			seriesID, child2.ID,
		).Scan(&child2EnrollmentID)
		require.NoError(t, err)

		// Parent2 accepts for child2
		enrollment, err := seriesService.AcceptInvitation(ctx, child2EnrollmentID.String(), parent2.ID.String())
		require.NoError(t, err)
		assert.Equal(t, "accepted", enrollment.Status)

		t.Logf("✓ Parent2 accepted invitation for child2")
	})

	// ─── Test: Teacher accepts student request ──────────────────
	t.Run("TeacherAcceptsRequest", func(t *testing.T) {
		// Get independent student's enrollment ID
		var enrollmentID uuid.UUID
		err := testDB.Pool.QueryRow(ctx,
			`SELECT id FROM session_enrollments WHERE series_id = $1 AND student_id = $2`,
			seriesID, independentStudent.ID,
		).Scan(&enrollmentID)
		require.NoError(t, err)

		enrollment, err := seriesService.AcceptRequest(ctx, seriesID.String(), enrollmentID.String(), teacher.ID.String())
		require.NoError(t, err)
		assert.Equal(t, "accepted", enrollment.Status)

		t.Logf("✓ Teacher accepted independent student's request")
	})

	// ─── Test: Verify enrolled count ────────────────────────────
	t.Run("VerifyEnrolledCount", func(t *testing.T) {
		series, err := seriesService.GetSeries(ctx, seriesID.String(), teacher.ID.String())
		require.NoError(t, err)

		assert.Equal(t, 3, series.EnrolledCount, "Should have 3 enrolled students")
		assert.Equal(t, 0, series.PendingCount, "No pending enrollments")

		t.Logf("✓ Series has %d enrolled students", series.EnrolledCount)
	})

	// ─── Test: Browse available series ──────────────────────────
	t.Run("BrowseAvailableSeries", func(t *testing.T) {
		series, total, err := seriesService.BrowseAvailableSeries(ctx, child1.ID.String(), "", "", "", 1, 20)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(1))

		found := false
		for _, s := range series {
			if s.ID == seriesID {
				found = true
				assert.Equal(t, "accepted", s.CurrentUserStatus, "Child1 should see their enrollment status")
			}
		}
		assert.True(t, found, "Should find our series in browse")

		t.Logf("✓ Browse returned %d series", len(series))
	})

	// ─── Test: List invitations for student ─────────────────────
	t.Run("ListInvitations", func(t *testing.T) {
		invitations, total, err := seriesService.ListMyInvitations(ctx, child1.ID.String(), "", 1, 20)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(1))

		found := false
		for _, inv := range invitations {
			if inv.SeriesID == seriesID {
				found = true
				assert.Equal(t, "accepted", inv.Status)
			}
		}
		assert.True(t, found, "Should find invitation in list")

		t.Logf("✓ Found %d invitations for student", len(invitations))
	})

	// ─── Test: Teacher declines a student request ───────────────
	t.Run("TeacherDeclinesRequest", func(t *testing.T) {
		// Create a new student who requests to join
		newStudent := createStudentWithProfile(t, ctx, "New", "Student", nil)
		defer cleanupTestUser(t, ctx, newStudent.ID)

		enrollment, err := seriesService.RequestToJoin(ctx, seriesID.String(), newStudent.ID.String())
		require.NoError(t, err)

		// Teacher declines
		err = seriesService.DeclineRequest(ctx, seriesID.String(), enrollment.ID.String(), teacher.ID.String())
		require.NoError(t, err)

		// Verify status
		var status string
		testDB.Pool.QueryRow(ctx, `SELECT status::text FROM session_enrollments WHERE id = $1`, enrollment.ID).Scan(&status)
		assert.Equal(t, "declined", status)

		t.Log("✓ Teacher declined student request")
	})

	// ─── Test: Remove student from series ───────────────────────
	t.Run("RemoveStudent", func(t *testing.T) {
		err := seriesService.RemoveStudent(ctx, seriesID.String(), independentStudent.ID.String(), teacher.ID.String())
		require.NoError(t, err)

		// Verify status
		var status string
		testDB.Pool.QueryRow(ctx,
			`SELECT status::text FROM session_enrollments WHERE series_id = $1 AND student_id = $2`,
			seriesID, independentStudent.ID,
		).Scan(&status)
		assert.Equal(t, "removed", status)

		// Verify count updated
		series, _ := seriesService.GetSeries(ctx, seriesID.String(), teacher.ID.String())
		assert.Equal(t, 2, series.EnrolledCount, "Should have 2 enrolled students after removal")

		t.Log("✓ Removed independent student from series")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 4: Booking Requests (Student & Parent)
// ═══════════════════════════════════════════════════════════════

func TestBookingRequests(t *testing.T) {
	ctx := context.Background()

	// ─── Setup ──────────────────────────────────────────────────
	teacher := createTeacherWithProfile(t, ctx, "Booking", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	// Set availability for all weekdays
	for i := 0; i < 7; i++ {
		createTeacherAvailability(t, ctx, teacher.ID, i, "08:00", "20:00")
	}

	parent1 := createParentWithProfile(t, ctx, "Booking", "Parent1")
	defer cleanupTestUser(t, ctx, parent1.ID)
	child1 := createStudentWithProfile(t, ctx, "Booking", "Child1", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1.ID)

	parent2 := createParentWithProfile(t, ctx, "Booking", "Parent2")
	defer cleanupTestUser(t, ctx, parent2.ID)
	child2 := createStudentWithProfile(t, ctx, "Booking", "Child2", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2.ID)

	independentStudent := createStudentWithProfile(t, ctx, "Booking", "IndStudent", nil)
	defer cleanupTestUser(t, ctx, independentStudent.ID)

	nextMonday := getNextWeekday(time.Monday)
	var parentBookingID, studentBookingID string

	// ─── Test: Student creates booking ──────────────────────────
	t.Run("StudentCreatesBooking", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "09:00",
			EndTime:       "10:00",
			Message:       "J'ai besoin d'aide en maths",
			Purpose:       "revision",
		}
		result, err := bookingService.CreateBookingRequest(ctx, independentStudent.ID.String(), "student", req)
		require.NoError(t, err)

		assert.Equal(t, independentStudent.ID.String(), result.StudentID)
		assert.Nil(t, result.BookedByParentID)
		assert.Equal(t, "pending", result.Status)

		studentBookingID = result.ID
		t.Logf("✓ Student created booking %s", result.ID)
	})

	// ─── Test: Parent creates booking for child ─────────────────
	t.Run("ParentCreatesBookingForChild", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:30",
			EndTime:       "11:30",
			Message:       "Mon enfant prépare le BEM",
			Purpose:       "exam_prep",
			ForChildID:    child1.ID.String(),
		}
		result, err := bookingService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.NoError(t, err)

		assert.Equal(t, child1.ID.String(), result.StudentID)
		require.NotNil(t, result.BookedByParentID)
		assert.Equal(t, parent1.ID.String(), *result.BookedByParentID)
		assert.Contains(t, result.BookedByParentName, "Parent1")

		parentBookingID = result.ID
		t.Logf("✓ Parent1 created booking %s for child1", result.ID)
	})

	// ─── Test: Parent cannot book for other's child ─────────────
	t.Run("ParentCannotBookOthersChild", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "12:00",
			EndTime:       "13:00",
			ForChildID:    child2.ID.String(), // belongs to parent2
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "not the parent")

		t.Log("✓ Correctly blocked parent from booking other's child")
	})

	// ─── Test: Teacher accepts booking ──────────────────────────
	t.Run("TeacherAcceptsBooking", func(t *testing.T) {
		req := booking.AcceptBookingRequest{
			Title:       "Séance de révision",
			Description: "Révision mathématiques",
			Price:       2500,
		}
		result, err := bookingService.AcceptBookingRequest(ctx, studentBookingID, teacher.ID.String(), req)
		require.NoError(t, err)

		assert.Equal(t, "accepted", result.Status)
		assert.NotNil(t, result.SessionID)
		assert.NotNil(t, result.SeriesID, "Accepted booking should create a session series")

		t.Logf("✓ Teacher accepted booking, series=%s session=%s", *result.SeriesID, *result.SessionID)
	})

	// ─── Test: Teacher declines booking ─────────────────────────
	t.Run("TeacherDeclinesBooking", func(t *testing.T) {
		req := booking.DeclineBookingRequest{
			Reason: "Je ne suis pas disponible à cette date",
		}
		result, err := bookingService.DeclineBookingRequest(ctx, parentBookingID, teacher.ID.String(), req)
		require.NoError(t, err)

		assert.Equal(t, "declined", result.Status)
		assert.Equal(t, req.Reason, result.DeclineReason)

		t.Log("✓ Teacher declined booking with reason")
	})

	// ─── Test: List bookings as teacher ─────────────────────────
	t.Run("ListAsTeacher", func(t *testing.T) {
		query := booking.ListBookingsQuery{Role: "as_teacher", Page: 1, Limit: 20}
		results, total, err := bookingService.ListBookingRequests(ctx, teacher.ID.String(), query)
		require.NoError(t, err)

		assert.GreaterOrEqual(t, total, int64(2))

		// Check parent info on parent booking
		for _, b := range results {
			if b.BookedByParentID != nil {
				assert.NotEmpty(t, b.BookedByParentName)
			}
		}

		t.Logf("✓ Teacher sees %d bookings", len(results))
	})

	// ─── Test: List bookings as parent ──────────────────────────
	t.Run("ListAsParent", func(t *testing.T) {
		query := booking.ListBookingsQuery{Role: "as_parent", Page: 1, Limit: 20}
		results, total, err := bookingService.ListBookingRequests(ctx, parent1.ID.String(), query)
		require.NoError(t, err)

		assert.GreaterOrEqual(t, total, int64(1))
		for _, b := range results {
			require.NotNil(t, b.BookedByParentID)
			assert.Equal(t, parent1.ID.String(), *b.BookedByParentID)
		}

		t.Logf("✓ Parent sees %d bookings they made", len(results))
	})

	// ─── Test: Student cancels booking ──────────────────────────
	t.Run("StudentCancelsBooking", func(t *testing.T) {
		// Create a new booking to cancel
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "14:00",
			EndTime:       "15:00",
		}
		created, err := bookingService.CreateBookingRequest(ctx, independentStudent.ID.String(), "student", req)
		require.NoError(t, err)

		err = bookingService.CancelBookingRequest(ctx, created.ID, independentStudent.ID.String())
		require.NoError(t, err)

		// Verify
		booking, _ := bookingService.GetBookingRequest(ctx, created.ID, independentStudent.ID.String())
		assert.Equal(t, "cancelled", booking.Status)

		t.Log("✓ Student cancelled their booking")
	})

	// ─── Test: Time conflict detection ──────────────────────────
	t.Run("TimeConflict", func(t *testing.T) {
		// The 09:00-10:00 slot is already accepted, try overlapping
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "09:30",
			EndTime:       "10:30",
			ForChildID:    child2.ID.String(),
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrAlreadyBooked)

		t.Log("✓ Time conflict correctly detected")
	})

	// ─── Test: Outside availability ─────────────────────────────
	t.Run("OutsideAvailability", func(t *testing.T) {
		// Clear and set limited availability
		testDB.Pool.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, teacher.ID)
		createTeacherAvailability(t, ctx, teacher.ID, int(nextMonday.Weekday()), "09:00", "12:00")

		// Try to book at 20:00
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "20:00",
			EndTime:       "21:00",
			ForChildID:    child2.ID.String(),
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrSlotNotAvailable)

		t.Log("✓ Booking outside availability correctly rejected")
	})

	// ─── Test: Accept booking with existing series (group merge) ─
	t.Run("AcceptBookingIntoExistingSeries", func(t *testing.T) {
		// Restore full availability
		testDB.Pool.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, teacher.ID)
		createTeacherAvailability(t, ctx, teacher.ID, int(nextMonday.Weekday()), "08:00", "22:00")

		// Create a group series for the teacher
		seriesReq := sessionseries.CreateSeriesRequest{
			Title:         "Groupe Math",
			SessionType:   "group",
			DurationHours: 2.0,
			MaxStudents:   10,
			PricePerHour:  2000,
		}
		series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), seriesReq)
		require.NoError(t, err)

		// A new student creates a booking
		newStudent := createStudentWithProfile(t, ctx, "Merge", "Student", nil)
		defer cleanupTestUser(t, ctx, newStudent.ID)

		bookReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "11:00",
			EndTime:       "12:00",
		}
		created, err := bookingService.CreateBookingRequest(ctx, newStudent.ID.String(), "student", bookReq)
		require.NoError(t, err)

		// Teacher accepts and merges into existing series
		acceptReq := booking.AcceptBookingRequest{
			Title:            "Séance de groupe",
			Price:            2000,
			ExistingSeriesID: series.ID.String(),
		}
		result, err := bookingService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), acceptReq)
		require.NoError(t, err)

		assert.Equal(t, "accepted", result.Status)
		assert.NotNil(t, result.SeriesID)
		assert.Equal(t, series.ID.String(), *result.SeriesID, "Should be merged into existing series")

		t.Logf("✓ Booking merged into existing series %s", *result.SeriesID)
	})

	// ─── Test: Booking conversation messages ────────────────────
	t.Run("BookingConversationMessages", func(t *testing.T) {
		// Create a fresh booking for conversation test
		newStudent := createStudentWithProfile(t, ctx, "Chat", "Student", nil)
		defer cleanupTestUser(t, ctx, newStudent.ID)

		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "14:00",
			EndTime:       "15:00",
			Message:       "I need help",
		}
		created, err := bookingService.CreateBookingRequest(ctx, newStudent.ID.String(), "student", req)
		require.NoError(t, err)

		// Student sends first message
		msg1, err := bookingService.SendMessage(ctx, created.ID, newStudent.ID.String(), booking.SendMessageRequest{
			Content: "Bonjour, est-ce que vous pouvez m'aider en maths?",
		})
		require.NoError(t, err)
		assert.Equal(t, created.ID, msg1.BookingID)
		assert.Equal(t, newStudent.ID.String(), msg1.SenderID)
		assert.Contains(t, msg1.SenderName, "Chat")
		t.Logf("✓ Student sent message: %s", msg1.Content)

		// Teacher replies
		msg2, err := bookingService.SendMessage(ctx, created.ID, teacher.ID.String(), booking.SendMessageRequest{
			Content: "Oui bien sûr, quel chapitre?",
		})
		require.NoError(t, err)
		assert.Equal(t, teacher.ID.String(), msg2.SenderID)
		assert.Equal(t, "teacher", msg2.SenderRole)
		t.Logf("✓ Teacher replied: %s", msg2.Content)

		// Student sends another message
		_, err = bookingService.SendMessage(ctx, created.ID, newStudent.ID.String(), booking.SendMessageRequest{
			Content: "Les fonctions et les dérivées",
		})
		require.NoError(t, err)

		// List messages — should have 3
		msgs, err := bookingService.ListMessages(ctx, created.ID, newStudent.ID.String(), booking.ListMessagesQuery{Limit: 50})
		require.NoError(t, err)
		assert.Len(t, msgs, 3, "Should have 3 messages in the conversation")
		assert.Equal(t, "Bonjour, est-ce que vous pouvez m'aider en maths?", msgs[0].Content)
		assert.Equal(t, "Oui bien sûr, quel chapitre?", msgs[1].Content)
		assert.Equal(t, "Les fonctions et les dérivées", msgs[2].Content)
		t.Logf("✓ Listed %d messages in conversation", len(msgs))

		// Teacher can also list messages
		teacherMsgs, err := bookingService.ListMessages(ctx, created.ID, teacher.ID.String(), booking.ListMessagesQuery{Limit: 50})
		require.NoError(t, err)
		assert.Len(t, teacherMsgs, 3)
		t.Log("✓ Teacher can also read the conversation")

		// Unauthorized user cannot read messages
		stranger := createStudentWithProfile(t, ctx, "Stranger", "User", nil)
		defer cleanupTestUser(t, ctx, stranger.ID)

		_, err = bookingService.ListMessages(ctx, created.ID, stranger.ID.String(), booking.ListMessagesQuery{})
		assert.Error(t, err, "Stranger should not be able to read messages")

		_, err = bookingService.SendMessage(ctx, created.ID, stranger.ID.String(), booking.SendMessageRequest{
			Content: "Hacking attempt",
		})
		assert.Error(t, err, "Stranger should not be able to send messages")
		t.Log("✓ Unauthorized users are blocked from the conversation")
	})

	// ─── Test: Auto-merge group bookings at same time slot ──────
	t.Run("AutoMergeGroupSameTimeSlot", func(t *testing.T) {
		// Restore full availability
		testDB.Pool.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, teacher.ID)
		createTeacherAvailability(t, ctx, teacher.ID, int(nextMonday.Weekday()), "08:00", "22:00")

		// Student A books group at 16:00-17:00
		studentA := createStudentWithProfile(t, ctx, "MergeA", "Student", nil)
		defer cleanupTestUser(t, ctx, studentA.ID)

		reqA := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "16:00",
			EndTime:       "17:00",
			Message:       "Groupe maths A",
		}
		bookingA, err := bookingService.CreateBookingRequest(ctx, studentA.ID.String(), "student", reqA)
		require.NoError(t, err)

		// Teacher accepts booking A → creates new series + session
		resultA, err := bookingService.AcceptBookingRequest(ctx, bookingA.ID, teacher.ID.String(), booking.AcceptBookingRequest{
			Title: "Groupe Maths 16h",
			Price: 2000,
		})
		require.NoError(t, err)
		require.NotNil(t, resultA.SessionID)
		require.NotNil(t, resultA.SeriesID)
		sessionA := *resultA.SessionID
		seriesA := *resultA.SeriesID
		t.Logf("✓ Booking A accepted → series=%s session=%s", seriesA, sessionA)

		// Student B books group at SAME time 16:00-17:00
		studentB := createStudentWithProfile(t, ctx, "MergeB", "Student", nil)
		defer cleanupTestUser(t, ctx, studentB.ID)

		reqB := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "16:00",
			EndTime:       "17:00",
			Message:       "Groupe maths B",
		}
		bookingB, err := bookingService.CreateBookingRequest(ctx, studentB.ID.String(), "student", reqB)
		require.NoError(t, err)

		// Teacher accepts booking B → should auto-merge into same session
		resultB, err := bookingService.AcceptBookingRequest(ctx, bookingB.ID, teacher.ID.String(), booking.AcceptBookingRequest{
			Title: "Groupe Maths 16h",
			Price: 2000,
		})
		require.NoError(t, err)
		require.NotNil(t, resultB.SessionID)
		require.NotNil(t, resultB.SeriesID)

		assert.Equal(t, sessionA, *resultB.SessionID, "Student B should be in the SAME session as A")
		assert.Equal(t, seriesA, *resultB.SeriesID, "Student B should be in the SAME series as A")
		t.Logf("✓ Booking B auto-merged → same session=%s same series=%s", *resultB.SessionID, *resultB.SeriesID)

		// Verify both students are participants of the same session
		var participantCount int
		err = testDB.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM session_participants WHERE session_id = $1`,
			sessionA,
		).Scan(&participantCount)
		require.NoError(t, err)
		assert.Equal(t, 2, participantCount, "Session should have 2 participants (A and B)")
		t.Logf("✓ Session has %d participants", participantCount)

		// Verify both are enrolled in the same series
		var enrollCount int
		err = testDB.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM session_enrollments WHERE series_id = $1 AND status = 'accepted'`,
			seriesA,
		).Scan(&enrollCount)
		require.NoError(t, err)
		assert.Equal(t, 2, enrollCount, "Series should have 2 enrollments")
		t.Logf("✓ Series has %d enrollments", enrollCount)
	})

	// ─── Test: One-on-one blocks double-booking at same time ────
	t.Run("OneOnOneBlocksDoubleBooking", func(t *testing.T) {
		// Student C books individual at 18:00-19:00
		studentC := createStudentWithProfile(t, ctx, "BlockC", "Student", nil)
		defer cleanupTestUser(t, ctx, studentC.ID)

		reqC := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "18:00",
			EndTime:       "19:00",
		}
		bookingC, err := bookingService.CreateBookingRequest(ctx, studentC.ID.String(), "student", reqC)
		require.NoError(t, err)

		// Accept booking C → creates 1-on-1 session at 18:00
		_, err = bookingService.AcceptBookingRequest(ctx, bookingC.ID, teacher.ID.String(), booking.AcceptBookingRequest{
			Price: 2500,
		})
		require.NoError(t, err)
		t.Log("✓ 1-on-1 booking C accepted at 18:00-19:00")

		// Student D tries to book individual at same time 18:00-19:00
		// Should be blocked at CREATION level (conflict with accepted individual)
		studentD := createStudentWithProfile(t, ctx, "BlockD", "Student", nil)
		defer cleanupTestUser(t, ctx, studentD.ID)

		reqD := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "18:00",
			EndTime:       "19:00",
		}
		_, err = bookingService.CreateBookingRequest(ctx, studentD.ID.String(), "student", reqD)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrAlreadyBooked)
		t.Logf("✓ Double-booking blocked at creation: %s", err.Error())
	})

	// ─── Test: Mismatched type blocks at accept level ───────────
	t.Run("MismatchedTypeBlocksAtAccept", func(t *testing.T) {
		// Create both bookings at 20:00-21:00 BEFORE any are accepted
		// (pending bookings don't trigger conflict checks)
		studentF := createStudentWithProfile(t, ctx, "MixF", "Student", nil)
		defer cleanupTestUser(t, ctx, studentF.ID)
		studentG := createStudentWithProfile(t, ctx, "MixG", "Student", nil)
		defer cleanupTestUser(t, ctx, studentG.ID)

		// Individual booking at 20:00
		reqF := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "20:00",
			EndTime:       "21:00",
		}
		bookingF, err := bookingService.CreateBookingRequest(ctx, studentF.ID.String(), "student", reqF)
		require.NoError(t, err)

		// Group booking at same time 20:00
		reqG := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "20:00",
			EndTime:       "21:00",
		}
		bookingG, err := bookingService.CreateBookingRequest(ctx, studentG.ID.String(), "student", reqG)
		require.NoError(t, err)

		// Accept the GROUP booking first → creates group session at 20:00
		_, err = bookingService.AcceptBookingRequest(ctx, bookingG.ID, teacher.ID.String(), booking.AcceptBookingRequest{
			Title: "Groupe 20h",
			Price: 2000,
		})
		require.NoError(t, err)
		t.Log("✓ Group booking G accepted at 20:00-21:00")

		// Now try to accept the INDIVIDUAL booking at same time
		// Should fail: can't start 1-on-1 when group session exists
		_, err = bookingService.AcceptBookingRequest(ctx, bookingF.ID, teacher.ID.String(), booking.AcceptBookingRequest{
			Price: 2500,
		})
		require.Error(t, err)
		assert.Contains(t, err.Error(), "séance de groupe")
		t.Logf("✓ Mismatched type blocked at accept: %s", err.Error())
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 5: Individual vs Group Sessions
// ═══════════════════════════════════════════════════════════════

func TestSessionTypes(t *testing.T) {
	ctx := context.Background()

	teacher := createTeacherWithProfile(t, ctx, "Type", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	// ─── Test: One-on-one series restricts to 1 student ─────────
	t.Run("OneOnOneMaxOne", func(t *testing.T) {
		req := sessionseries.CreateSeriesRequest{
			Title:         "Cours particulier",
			SessionType:   "one_on_one",
			DurationHours: 1.5,
			MaxStudents:   5, // Will be forced to 1
			PricePerHour:  3000,
		}
		series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), req)
		require.NoError(t, err)

		assert.Equal(t, 1, series.MaxStudents, "One-on-one should force max_students=1")
		assert.Equal(t, 1, series.MinStudents, "One-on-one should force min_students=1")

		t.Log("✓ One-on-one series correctly limited to 1 student")
	})

	// ─── Test: Group series allows multiple students ────────────
	t.Run("GroupMultipleStudents", func(t *testing.T) {
		req := sessionseries.CreateSeriesRequest{
			Title:         "Cours de groupe",
			SessionType:   "group",
			DurationHours: 2,
			MinStudents:   3,
			MaxStudents:   15,
			PricePerHour:  1500,
		}
		series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), req)
		require.NoError(t, err)

		assert.Equal(t, 15, series.MaxStudents)
		assert.Equal(t, 3, series.MinStudents)

		t.Log("✓ Group series allows multiple students")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 6: Edge Cases and Error Handling
// ═══════════════════════════════════════════════════════════════

func TestEdgeCases(t *testing.T) {
	ctx := context.Background()

	teacher := createTeacherWithProfile(t, ctx, "Edge", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	parent := createParentWithProfile(t, ctx, "Edge", "Parent")
	defer cleanupTestUser(t, ctx, parent.ID)
	child := createStudentWithProfile(t, ctx, "Edge", "Child", &parent.ID)
	defer cleanupTestUser(t, ctx, child.ID)

	// ─── Test: Invalid UUIDs ────────────────────────────────────
	t.Run("InvalidUUIDs", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:   "not-a-uuid",
			SessionType: "individual",
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
		require.Error(t, err)

		t.Log("✓ Invalid teacher UUID rejected")
	})

	// ─── Test: Non-existent teacher ─────────────────────────────
	t.Run("NonExistentTeacher", func(t *testing.T) {
		fakeTeacher := uuid.New()
		createTeacherAvailability(t, ctx, teacher.ID, 1, "09:00", "17:00")

		req := booking.CreateBookingRequest{
			TeacherID:     fakeTeacher.String(),
			SessionType:   "individual",
			RequestedDate: getNextWeekday(time.Monday).Format("2006-01-02"),
			StartTime:     "09:00",
			EndTime:       "10:00",
			ForChildID:    child.ID.String(),
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
		require.Error(t, err)

		t.Log("✓ Non-existent teacher rejected")
	})

	// ─── Test: Parent must specify child ────────────────────────
	t.Run("ParentMustSpecifyChild", func(t *testing.T) {
		createTeacherAvailability(t, ctx, teacher.ID, 1, "09:00", "17:00")

		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: getNextWeekday(time.Monday).Format("2006-01-02"),
			StartTime:     "11:00",
			EndTime:       "12:00",
			// ForChildID missing!
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "for_child_id")

		t.Log("✓ Parent without for_child_id rejected")
	})

	// ─── Test: Invalid date format ──────────────────────────────
	t.Run("InvalidDateFormat", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: "14-02-2026", // Wrong format
			StartTime:     "09:00",
			EndTime:       "10:00",
			ForChildID:    child.ID.String(),
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "requested_date")

		t.Log("✓ Invalid date format rejected")
	})

	// ─── Test: Series not found ─────────────────────────────────
	t.Run("SeriesNotFound", func(t *testing.T) {
		fakeSeriesID := uuid.New()
		_, err := seriesService.GetSeries(ctx, fakeSeriesID.String(), teacher.ID.String())
		require.Error(t, err)
		assert.ErrorIs(t, err, sessionseries.ErrSeriesNotFound)

		t.Log("✓ Non-existent series returns error")
	})

	// ─── Test: Unauthorized series access ───────────────────────
	t.Run("UnauthorizedSeriesModification", func(t *testing.T) {
		// Create series with teacher
		series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
			Title:         "Test",
			SessionType:   "group",
			DurationHours: 1,
			MaxStudents:   5,
		})
		require.NoError(t, err)

		// Create another teacher
		otherTeacher := createTeacherWithProfile(t, ctx, "Other", "Teacher")
		defer cleanupTestUser(t, ctx, otherTeacher.ID)

		// Other teacher tries to add sessions
		_, err = seriesService.AddSessions(ctx, series.ID.String(), otherTeacher.ID.String(), sessionseries.AddSessionsRequest{
			Sessions: []sessionseries.SessionDateInput{{StartTime: time.Now().Add(24 * time.Hour).Format(time.RFC3339)}},
		})
		require.Error(t, err)
		assert.ErrorIs(t, err, sessionseries.ErrNotAuthorized)

		t.Log("✓ Unauthorized series modification rejected")
	})

	// ─── Test: Already enrolled ─────────────────────────────────
	t.Run("AlreadyRequested", func(t *testing.T) {
		student := createStudentWithProfile(t, ctx, "Double", "Student", nil)
		defer cleanupTestUser(t, ctx, student.ID)

		series, _ := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
			Title:         "Test Series",
			SessionType:   "group",
			DurationHours: 1,
			MaxStudents:   5,
		})

		// First request
		_, err := seriesService.RequestToJoin(ctx, series.ID.String(), student.ID.String())
		require.NoError(t, err)

		// Second request should fail
		_, err = seriesService.RequestToJoin(ctx, series.ID.String(), student.ID.String())
		require.Error(t, err)
		assert.ErrorIs(t, err, sessionseries.ErrAlreadyRequested)

		t.Log("✓ Double request rejected")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 7: Multi-Parent Multi-Child Scenarios
// ═══════════════════════════════════════════════════════════════

func TestMultiParentMultiChild(t *testing.T) {
	ctx := context.Background()

	teacher := createTeacherWithProfile(t, ctx, "Multi", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	// Set availability
	for i := 0; i < 7; i++ {
		createTeacherAvailability(t, ctx, teacher.ID, i, "06:00", "22:00")
	}

	// Parent 1 with 3 children
	parent1 := createParentWithProfile(t, ctx, "Multi", "Parent1")
	defer cleanupTestUser(t, ctx, parent1.ID)
	child1a := createStudentWithProfile(t, ctx, "Child1A", "Parent1", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1a.ID)
	child1b := createStudentWithProfile(t, ctx, "Child1B", "Parent1", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1b.ID)
	child1c := createStudentWithProfile(t, ctx, "Child1C", "Parent1", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1c.ID)

	// Parent 2 with 2 children
	parent2 := createParentWithProfile(t, ctx, "Multi", "Parent2")
	defer cleanupTestUser(t, ctx, parent2.ID)
	child2a := createStudentWithProfile(t, ctx, "Child2A", "Parent2", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2a.ID)
	child2b := createStudentWithProfile(t, ctx, "Child2B", "Parent2", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2b.ID)

	t.Log("Created: Parent1 (3 children), Parent2 (2 children)")

	nextMonday := getNextWeekday(time.Monday)
	timeSlot := 6 // Start at 06:00

	// ─── Test: Parent1 books for all 3 children ─────────────────
	t.Run("Parent1BooksAllChildren", func(t *testing.T) {
		children := []TestUser{child1a, child1b, child1c}
		for i, child := range children {
			req := booking.CreateBookingRequest{
				TeacherID:     teacher.ID.String(),
				SessionType:   "individual",
				RequestedDate: nextMonday.Format("2006-01-02"),
				StartTime:     fmt.Sprintf("%02d:00", timeSlot+i),
				EndTime:       fmt.Sprintf("%02d:30", timeSlot+i),
				ForChildID:    child.ID.String(),
			}
			result, err := bookingService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
			require.NoError(t, err)
			assert.Equal(t, child.ID.String(), result.StudentID)
			require.NotNil(t, result.BookedByParentID)
			assert.Equal(t, parent1.ID.String(), *result.BookedByParentID)
		}
		t.Log("✓ Parent1 booked for all 3 children")
	})

	// ─── Test: Parent2 books for their 2 children ───────────────
	t.Run("Parent2BooksAllChildren", func(t *testing.T) {
		children := []TestUser{child2a, child2b}
		for i, child := range children {
			req := booking.CreateBookingRequest{
				TeacherID:     teacher.ID.String(),
				SessionType:   "group",
				RequestedDate: nextMonday.Format("2006-01-02"),
				StartTime:     fmt.Sprintf("%02d:00", timeSlot+5+i),
				EndTime:       fmt.Sprintf("%02d:30", timeSlot+5+i),
				ForChildID:    child.ID.String(),
			}
			result, err := bookingService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req)
			require.NoError(t, err)
			require.NotNil(t, result.BookedByParentID)
			assert.Equal(t, parent2.ID.String(), *result.BookedByParentID)
		}
		t.Log("✓ Parent2 booked for both children")
	})

	// ─── Test: Each parent only sees their bookings ─────────────
	t.Run("ParentIsolation", func(t *testing.T) {
		query := booking.ListBookingsQuery{Role: "as_parent", Page: 1, Limit: 50}

		// Parent1's bookings
		results1, _, err := bookingService.ListBookingRequests(ctx, parent1.ID.String(), query)
		require.NoError(t, err)
		assert.Len(t, results1, 3, "Parent1 should see 3 bookings")
		for _, b := range results1 {
			require.NotNil(t, b.BookedByParentID)
			assert.Equal(t, parent1.ID.String(), *b.BookedByParentID)
		}

		// Parent2's bookings
		results2, _, err := bookingService.ListBookingRequests(ctx, parent2.ID.String(), query)
		require.NoError(t, err)
		assert.Len(t, results2, 2, "Parent2 should see 2 bookings")
		for _, b := range results2 {
			require.NotNil(t, b.BookedByParentID)
			assert.Equal(t, parent2.ID.String(), *b.BookedByParentID)
		}

		t.Logf("✓ Parent1 sees %d, Parent2 sees %d (isolated)", len(results1), len(results2))
	})

	// ─── Test: Teacher sees all with parent info ────────────────
	t.Run("TeacherSeesAll", func(t *testing.T) {
		query := booking.ListBookingsQuery{Role: "as_teacher", Page: 1, Limit: 50}
		results, total, err := bookingService.ListBookingRequests(ctx, teacher.ID.String(), query)
		require.NoError(t, err)

		assert.GreaterOrEqual(t, total, int64(5), "Teacher should see at least 5 bookings")

		// Count by parent
		parent1Count, parent2Count := 0, 0
		for _, b := range results {
			if b.BookedByParentID != nil {
				if *b.BookedByParentID == parent1.ID.String() {
					parent1Count++
				} else if *b.BookedByParentID == parent2.ID.String() {
					parent2Count++
				}
			}
		}
		assert.Equal(t, 3, parent1Count, "3 from parent1")
		assert.Equal(t, 2, parent2Count, "2 from parent2")

		t.Logf("✓ Teacher sees all: %d from parent1, %d from parent2", parent1Count, parent2Count)
	})

	// ─── Test: Cross-parent booking prevention ──────────────────
	t.Run("CrossParentPrevention", func(t *testing.T) {
		// Parent1 tries to book for Parent2's child
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "15:00",
			EndTime:       "16:00",
			ForChildID:    child2a.ID.String(), // belongs to parent2!
		}
		_, err := bookingService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)

		// Parent2 tries to book for Parent1's child
		req.ForChildID = child1a.ID.String() // belongs to parent1!
		_, err = bookingService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req)
		require.Error(t, err)

		t.Log("✓ Cross-parent booking correctly prevented")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 8: Teacher Profile Operations
// ═══════════════════════════════════════════════════════════════

func TestTeacherProfile(t *testing.T) {
	ctx := context.Background()

	teacherUser := createTeacherWithProfile(t, ctx, "Profile", "Teacher")
	defer cleanupTestUser(t, ctx, teacherUser.ID)

	// ─── Test: Get profile ──────────────────────────────────────
	t.Run("GetProfile", func(t *testing.T) {
		profile, err := teacherService.GetProfile(ctx, teacherUser.ID.String())
		require.NoError(t, err)

		assert.Equal(t, teacherUser.ID, profile.UserID)
		assert.Equal(t, "Profile", profile.FirstName)
		assert.Equal(t, "verified", profile.VerificationStatus)

		t.Logf("✓ Got profile for %s %s", profile.FirstName, profile.LastName)
	})

	// ─── Test: Update profile ───────────────────────────────────
	t.Run("UpdateProfile", func(t *testing.T) {
		bio := "Professeur certifié avec 10 ans d'expérience"
		years := 10
		specs := []string{"Mathématiques", "Physique", "Chimie"}

		req := teacherpkg.UpdateTeacherProfileRequest{
			Bio:             &bio,
			ExperienceYears: &years,
			Specializations: specs,
		}
		profile, err := teacherService.UpdateProfile(ctx, teacherUser.ID.String(), req)
		require.NoError(t, err)

		assert.Equal(t, bio, profile.Bio)
		assert.Equal(t, 10, profile.ExperienceYears)
		assert.ElementsMatch(t, specs, profile.Specializations)

		t.Log("✓ Updated profile with bio, experience, specializations")
	})

	// ─── Test: Profile not found ────────────────────────────────
	t.Run("ProfileNotFound", func(t *testing.T) {
		fakeID := uuid.New()
		_, err := teacherService.GetProfile(ctx, fakeID.String())
		require.Error(t, err)
		assert.ErrorIs(t, err, teacherpkg.ErrProfileNotFound)

		t.Log("✓ Non-existent profile returns error")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 9: Status Transitions
// ═══════════════════════════════════════════════════════════════

func TestStatusTransitions(t *testing.T) {
	ctx := context.Background()

	teacher := createTeacherWithProfile(t, ctx, "Status", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	for i := 0; i < 7; i++ {
		createTeacherAvailability(t, ctx, teacher.ID, i, "08:00", "20:00")
	}

	student := createStudentWithProfile(t, ctx, "Status", "Student", nil)
	defer cleanupTestUser(t, ctx, student.ID)

	nextMonday := getNextWeekday(time.Monday)

	// ─── Test: Cannot accept non-pending booking ────────────────
	t.Run("CannotAcceptNonPending", func(t *testing.T) {
		// Create and accept a booking
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "08:00",
			EndTime:       "09:00",
		}
		created, _ := bookingService.CreateBookingRequest(ctx, student.ID.String(), "student", req)
		bookingService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), booking.AcceptBookingRequest{Price: 1000})

		// Try to accept again
		_, err := bookingService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), booking.AcceptBookingRequest{Price: 1000})
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrInvalidStatus)

		t.Log("✓ Cannot accept already accepted booking")
	})

	// ─── Test: Cannot decline non-pending booking ───────────────
	t.Run("CannotDeclineNonPending", func(t *testing.T) {
		// Create and cancel a booking
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:00",
			EndTime:       "11:00",
		}
		created, _ := bookingService.CreateBookingRequest(ctx, student.ID.String(), "student", req)
		bookingService.CancelBookingRequest(ctx, created.ID, student.ID.String())

		// Try to decline
		_, err := bookingService.DeclineBookingRequest(ctx, created.ID, teacher.ID.String(), booking.DeclineBookingRequest{Reason: "test"})
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrInvalidStatus)

		t.Log("✓ Cannot decline cancelled booking")
	})

	// ─── Test: Series status transitions ────────────────────────
	t.Run("SeriesStatusTransition", func(t *testing.T) {
		// Create series (starts as draft)
		series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
			Title:         "Status Test",
			SessionType:   "group",
			DurationHours: 1,
			MaxStudents:   5,
		})
		require.NoError(t, err)
		assert.Equal(t, "draft", series.Status)

		// Add sessions (becomes active)
		series, err = seriesService.AddSessions(ctx, series.ID.String(), teacher.ID.String(), sessionseries.AddSessionsRequest{
			Sessions: []sessionseries.SessionDateInput{
				{StartTime: time.Now().Add(48 * time.Hour).Format(time.RFC3339)},
			},
		})
		require.NoError(t, err)
		assert.Equal(t, "active", series.Status)

		t.Log("✓ Series: draft → active on adding sessions")
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 10: Bug Fix Validations
// ═══════════════════════════════════════════════════════════════

func TestBugFixValidations(t *testing.T) {
	ctx := context.Background()

	teacher := createTeacherWithProfile(t, ctx, "Fix", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	for i := 0; i < 7; i++ {
		createTeacherAvailability(t, ctx, teacher.ID, i, "06:00", "23:00")
	}

	nextMonday := getNextWeekday(time.Monday)

	// ─── Test: Parent can cancel booking they created ───────────
	t.Run("ParentCancelsOwnBooking", func(t *testing.T) {
		parent := createParentWithProfile(t, ctx, "CancelFix", "Parent")
		defer cleanupTestUser(t, ctx, parent.ID)
		child := createStudentWithProfile(t, ctx, "CancelFix", "Child", &parent.ID)
		defer cleanupTestUser(t, ctx, child.ID)

		// Parent creates booking for child
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "06:00",
			EndTime:       "07:00",
			ForChildID:    child.ID.String(),
		}
		created, err := bookingService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
		require.NoError(t, err)
		require.NotNil(t, created.BookedByParentID)
		assert.Equal(t, parent.ID.String(), *created.BookedByParentID)

		// Parent cancels booking (was broken before fix — WHERE only checked student_id)
		err = bookingService.CancelBookingRequest(ctx, created.ID, parent.ID.String())
		require.NoError(t, err, "Parent should be able to cancel booking they created")

		// Verify status is cancelled
		b, err := bookingService.GetBookingRequest(ctx, created.ID, parent.ID.String())
		require.NoError(t, err)
		assert.Equal(t, "cancelled", b.Status)

		t.Log("✓ Parent successfully cancelled booking they created for their child")
	})

	// ─── Test: Student still cannot cancel parent's booking ─────
	t.Run("StudentCannotCancelParentBooking", func(t *testing.T) {
		parent := createParentWithProfile(t, ctx, "CancelIso", "Parent")
		defer cleanupTestUser(t, ctx, parent.ID)
		child := createStudentWithProfile(t, ctx, "CancelIso", "Child", &parent.ID)
		defer cleanupTestUser(t, ctx, child.ID)

		otherStudent := createStudentWithProfile(t, ctx, "CancelIso", "Other", nil)
		defer cleanupTestUser(t, ctx, otherStudent.ID)

		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "06:30",
			EndTime:       "07:30",
			ForChildID:    child.ID.String(),
		}
		created, err := bookingService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
		require.NoError(t, err)

		// Unrelated student tries to cancel — should fail
		err = bookingService.CancelBookingRequest(ctx, created.ID, otherStudent.ID.String())
		assert.ErrorIs(t, err, booking.ErrBookingNotFound,
			"Unrelated student should NOT be able to cancel parent's booking")

		t.Log("✓ Unrelated student correctly blocked from cancelling parent's booking")
	})

	// ─── Test: Session participants uniqueness constraint ────────
	t.Run("SessionParticipantsUniqueness", func(t *testing.T) {
		student := createStudentWithProfile(t, ctx, "Uniq", "Student", nil)
		defer cleanupTestUser(t, ctx, student.ID)

		// Create a booking and accept it (creates session + participant)
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "07:00",
			EndTime:       "08:00",
		}
		created, err := bookingService.CreateBookingRequest(ctx, student.ID.String(), "student", req)
		require.NoError(t, err)

		result, err := bookingService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), booking.AcceptBookingRequest{
			Price: 2000,
		})
		require.NoError(t, err)
		require.NotNil(t, result.SessionID)
		sessionID := *result.SessionID

		// Count participants — should be 1
		var count int
		err = testDB.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM session_participants WHERE session_id = $1 AND student_id = $2`,
			sessionID, student.ID,
		).Scan(&count)
		require.NoError(t, err)
		assert.Equal(t, 1, count)

		// Try to insert duplicate directly — ON CONFLICT DO NOTHING should prevent duplicate
		_, err = testDB.Pool.Exec(ctx,
			`INSERT INTO session_participants (session_id, student_id)
			 VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			sessionID, student.ID,
		)
		require.NoError(t, err, "ON CONFLICT DO NOTHING should not error")

		// Count again — still 1 (uniqueness enforced)
		err = testDB.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM session_participants WHERE session_id = $1 AND student_id = $2`,
			sessionID, student.ID,
		).Scan(&count)
		require.NoError(t, err)
		assert.Equal(t, 1, count, "Should still be 1 after duplicate insert attempt (UNIQUE constraint)")

		// Verify a raw duplicate INSERT (without ON CONFLICT) actually fails
		_, err = testDB.Pool.Exec(ctx,
			`INSERT INTO session_participants (session_id, student_id)
			 VALUES ($1, $2)`,
			sessionID, student.ID,
		)
		assert.Error(t, err, "Raw duplicate INSERT should fail due to UNIQUE constraint")

		t.Log("✓ Session participants uniqueness constraint is enforced")
	})

	// ─── Test: Message pagination with cursor ───────────────────
	t.Run("MessagePaginationCursor", func(t *testing.T) {
		student := createStudentWithProfile(t, ctx, "Pag", "Student", nil)
		defer cleanupTestUser(t, ctx, student.ID)

		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "08:00",
			EndTime:       "09:00",
		}
		created, err := bookingService.CreateBookingRequest(ctx, student.ID.String(), "student", req)
		require.NoError(t, err)

		// Send 5 messages with small delays for distinct timestamps
		for i := 1; i <= 5; i++ {
			_, err := bookingService.SendMessage(ctx, created.ID, student.ID.String(), booking.SendMessageRequest{
				Content: fmt.Sprintf("Message %d", i),
			})
			require.NoError(t, err)
			time.Sleep(10 * time.Millisecond) // Ensure distinct created_at
		}

		// List all messages (no cursor) — should get 5 in chronological order
		allMsgs, err := bookingService.ListMessages(ctx, created.ID, student.ID.String(), booking.ListMessagesQuery{Limit: 50})
		require.NoError(t, err)
		require.Len(t, allMsgs, 5)
		assert.Equal(t, "Message 1", allMsgs[0].Content, "First message should be oldest")
		assert.Equal(t, "Message 5", allMsgs[4].Content, "Last message should be newest")

		// Use "before" cursor on the 4th message → should get messages 1,2,3
		cursor := allMsgs[3].CreatedAt.Format(time.RFC3339Nano)
		olderMsgs, err := bookingService.ListMessages(ctx, created.ID, student.ID.String(), booking.ListMessagesQuery{
			Before: cursor,
			Limit:  50,
		})
		require.NoError(t, err)
		require.Len(t, olderMsgs, 3, "Should get 3 messages before Message 4")
		assert.Equal(t, "Message 1", olderMsgs[0].Content)
		assert.Equal(t, "Message 2", olderMsgs[1].Content)
		assert.Equal(t, "Message 3", olderMsgs[2].Content)

		// Use "before" cursor with limit=2 → should get the 2 messages immediately before cursor
		limitMsgs, err := bookingService.ListMessages(ctx, created.ID, student.ID.String(), booking.ListMessagesQuery{
			Before: cursor,
			Limit:  2,
		})
		require.NoError(t, err)
		require.Len(t, limitMsgs, 2, "Should get exactly 2 messages")
		assert.Equal(t, "Message 2", limitMsgs[0].Content, "Should be the 2 most recent before cursor")
		assert.Equal(t, "Message 3", limitMsgs[1].Content)

		t.Log("✓ Message pagination with cursor returns correct order and count")
	})

	// ─── Test: Subject name_fr column used correctly ────────────
	t.Run("SubjectNameFrColumn", func(t *testing.T) {
		// Verify subject names can be read from name_fr column
		var subjectName string
		var subjectID uuid.UUID
		err := testDB.Pool.QueryRow(ctx, `SELECT id, name_fr FROM subjects LIMIT 1`).Scan(&subjectID, &subjectName)
		require.NoError(t, err, "Should be able to read name_fr from subjects table")
		assert.NotEmpty(t, subjectName, "Subject name_fr should not be empty")

		t.Logf("✓ Subject '%s' (name_fr column) readable — used in session series queries", subjectName)
	})
}

// ═══════════════════════════════════════════════════════════════
// TEST SUITE 11: Payment Status Guards
// ═══════════════════════════════════════════════════════════════

func TestPaymentStatusGuards(t *testing.T) {
	ctx := context.Background()

	payer := createTestUser(t, ctx, "student", "Pay", "Payer")
	defer cleanupTestUser(t, ctx, payer.ID)
	payee := createTestUser(t, ctx, "teacher", "Pay", "Payee")
	defer cleanupTestUser(t, ctx, payee.ID)

	// ─── Test: Confirm only pending transactions ────────────────
	t.Run("ConfirmOnlyPending", func(t *testing.T) {
		// Create a payment
		tx, err := paymentService.InitiatePayment(ctx, payer.ID.String(), payment.InitiatePaymentRequest{
			PayeeID:       payee.ID,
			Amount:        1000,
			PaymentMethod: "ccp_baridimob",
		})
		require.NoError(t, err)
		assert.Equal(t, "pending", tx.Status)

		// Confirm it (should succeed)
		confirmed, err := paymentService.ConfirmPayment(ctx, payer.ID.String(), payment.ConfirmPaymentRequest{
			TransactionID:     tx.ID,
			ProviderReference: "REF-001",
		})
		require.NoError(t, err)
		assert.Equal(t, "completed", confirmed.Status)

		// Try to confirm again (should fail — not pending anymore)
		_, err = paymentService.ConfirmPayment(ctx, payer.ID.String(), payment.ConfirmPaymentRequest{
			TransactionID:     tx.ID,
			ProviderReference: "REF-002",
		})
		require.Error(t, err)
		assert.ErrorIs(t, err, payment.ErrNotPending, "Cannot confirm a completed transaction")

		t.Log("✓ ConfirmPayment only works on pending transactions")
	})

	// ─── Test: Refund only completed transactions ───────────────
	t.Run("RefundOnlyCompleted", func(t *testing.T) {
		// Create and confirm a transaction
		tx, err := paymentService.InitiatePayment(ctx, payer.ID.String(), payment.InitiatePaymentRequest{
			PayeeID:       payee.ID,
			Amount:        2000,
			PaymentMethod: "edahabia",
		})
		require.NoError(t, err)

		// Try to refund before confirming (still pending)
		_, err = paymentService.RefundPayment(ctx, payer.ID.String(), payment.RefundPaymentRequest{
			TransactionID: tx.ID,
			Amount:        2000,
			Reason:        "Changed my mind",
		})
		require.Error(t, err)
		assert.ErrorIs(t, err, payment.ErrNotCompleted, "Cannot refund a pending transaction")

		// Confirm it first
		_, err = paymentService.ConfirmPayment(ctx, payer.ID.String(), payment.ConfirmPaymentRequest{
			TransactionID:     tx.ID,
			ProviderReference: "REF-003",
		})
		require.NoError(t, err)

		// Now refund should succeed
		refunded, err := paymentService.RefundPayment(ctx, payer.ID.String(), payment.RefundPaymentRequest{
			TransactionID: tx.ID,
			Amount:        2000,
			Reason:        "Annulation du cours",
		})
		require.NoError(t, err)
		assert.Equal(t, "refunded", refunded.Status)

		// Try to refund again (already refunded)
		_, err = paymentService.RefundPayment(ctx, payer.ID.String(), payment.RefundPaymentRequest{
			TransactionID: tx.ID,
			Amount:        2000,
			Reason:        "Double refund",
		})
		require.Error(t, err)
		assert.ErrorIs(t, err, payment.ErrAlreadyRefunded, "Cannot refund an already refunded transaction")

		t.Log("✓ RefundPayment only works on completed transactions")
	})

	// ─── Test: Cannot confirm someone else's transaction ────────
	t.Run("CannotConfirmOthersTransaction", func(t *testing.T) {
		tx, err := paymentService.InitiatePayment(ctx, payer.ID.String(), payment.InitiatePaymentRequest{
			PayeeID:       payee.ID,
			Amount:        500,
			PaymentMethod: "ccp_baridimob",
		})
		require.NoError(t, err)

		// Payee (not payer) tries to confirm
		_, err = paymentService.ConfirmPayment(ctx, payee.ID.String(), payment.ConfirmPaymentRequest{
			TransactionID:     tx.ID,
			ProviderReference: "STOLEN",
		})
		require.Error(t, err)
		assert.ErrorIs(t, err, payment.ErrNotAuthorized)

		t.Log("✓ Cannot confirm another user's transaction")
	})
}

// ═══════════════════════════════════════════════════════════════
// Run summary
// ═══════════════════════════════════════════════════════════════
// Suite 12: Teacher Wallet & Star System
// ═══════════════════════════════════════════════════════════════

func TestWallet_GetOrCreateWallet(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletTeacher", "One")

	// First call creates the wallet
	w, err := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	require.NoError(t, err)
	assert.Equal(t, teacher.ID, w.TeacherID)
	assert.Equal(t, 0.0, w.Balance)
	assert.Equal(t, 0.0, w.TotalPurchased)
	assert.Equal(t, 0.0, w.TotalSpent)
	assert.Equal(t, 0.0, w.TotalRefunded)

	// Second call returns same wallet (idempotent)
	w2, err := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	require.NoError(t, err)
	assert.Equal(t, w.ID, w2.ID)
}

func TestWallet_ListPackages(t *testing.T) {
	ctx := context.Background()

	pkgs, err := walletService.ListPackages(ctx)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, len(pkgs), 4, "Should have at least 4 seeded packages")

	// Verify ordering
	assert.Equal(t, "Starter", pkgs[0].Name)
	assert.Equal(t, 600.0, pkgs[0].Amount)
	assert.Equal(t, 0.0, pkgs[0].Bonus)
	assert.Equal(t, 600.0, pkgs[0].TotalCredits)
	assert.Equal(t, 12, pkgs[0].GroupStars)  // 600/50
	assert.Equal(t, 8, pkgs[0].PrivateStars) // floor(600/70) = 8

	assert.Equal(t, "Premium", pkgs[3].Name)
	assert.Equal(t, 5000.0, pkgs[3].Amount)
	assert.Equal(t, 400.0, pkgs[3].Bonus)
	assert.Equal(t, 5400.0, pkgs[3].TotalCredits)
}

func TestWallet_BuyCredits_PendingUntilApproved(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletBuy", "Teacher")
	admin := createTestUser(t, ctx, "admin", "Admin", "Wallet")

	// Get a package
	pkgs, err := walletService.ListPackages(ctx)
	require.NoError(t, err)
	require.NotEmpty(t, pkgs)
	starterPkg := pkgs[0] // Starter: 600 DA

	// Buy credits
	tx, err := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     starterPkg.ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "BRDM-TEST-001",
	})
	require.NoError(t, err)
	assert.Equal(t, "purchase", tx.Type)
	assert.Equal(t, "pending", tx.Status)
	assert.Equal(t, 600.0, tx.Amount)

	// Balance should still be 0
	w, _ := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 0.0, w.Balance)

	// Admin approves
	approved, err := walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "Payment verified")
	require.NoError(t, err)
	assert.Equal(t, "completed", approved.Status)
	assert.Equal(t, 600.0, approved.BalanceAfter)
	assert.Equal(t, "Payment verified", approved.AdminNotes)

	// Balance should now be 600
	w, _ = walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 600.0, w.Balance)
	assert.Equal(t, 600.0, w.TotalPurchased)
}

func TestWallet_BuyCredits_AdminReject(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletReject", "Teacher")
	admin := createTestUser(t, ctx, "admin", "Admin", "Reject")

	pkgs, _ := walletService.ListPackages(ctx)
	tx, err := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "edahabia",
		ProviderRef:   "FAKE-REF",
	})
	require.NoError(t, err)

	// Admin rejects
	rejected, err := walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), false, "Fake receipt")
	require.NoError(t, err)
	assert.Equal(t, "failed", rejected.Status)

	// Balance stays 0
	w, _ := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 0.0, w.Balance)
}

func TestWallet_StarDeduction_OnAcceptRequest(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletStar", "Teacher")
	student := createStudentWithProfile(t, ctx, "WalletStar", "Student", nil)
	admin := createTestUser(t, ctx, "admin", "Admin", "Star")

	// Fund teacher wallet: 600 DA (12 group stars)
	pkgs, _ := walletService.ListPackages(ctx)
	tx, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "STAR-TEST-001",
	})
	walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "ok")

	// Create a group series
	series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
		Title:         "Maths Group",
		SessionType:   "group",
		DurationHours: 2,
		MaxStudents:   10,
		PricePerHour:  500,
	})
	require.NoError(t, err)

	// Student requests to join
	enr, err := seriesService.RequestToJoin(ctx, series.ID.String(), student.ID.String())
	require.NoError(t, err)
	assert.Equal(t, "requested", enr.Status)

	// Teacher accepts — star deducted
	accepted, err := seriesService.AcceptRequest(ctx, series.ID.String(), enr.ID.String(), teacher.ID.String())
	require.NoError(t, err)
	assert.Equal(t, "accepted", accepted.Status)

	// Balance should be 600 - 50 = 550
	w, _ := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 550.0, w.Balance)
	assert.Equal(t, 50.0, w.TotalSpent)
}

func TestWallet_StarDeduction_OnAcceptInvitation(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletInv", "Teacher")
	student := createStudentWithProfile(t, ctx, "WalletInv", "Student", nil)
	admin := createTestUser(t, ctx, "admin", "Admin", "Inv")

	// Fund 1000 + 20 bonus = 1020
	pkgs, _ := walletService.ListPackages(ctx)
	tx, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[1].ID, // Standard: 1000 + 20 bonus
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "INV-TEST-001",
	})
	walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "ok")

	// Create private series
	series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
		Title:         "Private Physics",
		SessionType:   "one_on_one",
		DurationHours: 1.5,
		MaxStudents:   1,
		PricePerHour:  800,
	})
	require.NoError(t, err)

	// Teacher invites student
	_, err = seriesService.InviteStudents(ctx, series.ID.String(), teacher.ID.String(), sessionseries.InviteStudentsRequest{
		StudentIDs: []string{student.ID.String()},
	})
	require.NoError(t, err)

	// Get enrollment ID
	s, _ := seriesService.GetSeries(ctx, series.ID.String(), teacher.ID.String())
	require.NotEmpty(t, s.Enrollments)
	enrollID := s.Enrollments[0].ID

	// Student accepts — private star (70 DZD) deducted
	_, err = seriesService.AcceptInvitation(ctx, enrollID.String(), student.ID.String())
	require.NoError(t, err)

	// Balance: 1020 - 70 = 950
	w, _ := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 950.0, w.Balance)
}

func TestWallet_InsufficientBalance_RejectsAccept(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletPoor", "Teacher")
	student := createStudentWithProfile(t, ctx, "WalletPoor", "Student", nil)

	// No credits added — wallet balance = 0

	// Create series
	series, err := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
		Title:         "No Money Series",
		SessionType:   "group",
		DurationHours: 1,
		MaxStudents:   5,
	})
	require.NoError(t, err)

	// Student requests
	enr, _ := seriesService.RequestToJoin(ctx, series.ID.String(), student.ID.String())

	// Teacher tries to accept — should fail with insufficient balance
	_, err = seriesService.AcceptRequest(ctx, series.ID.String(), enr.ID.String(), teacher.ID.String())
	require.Error(t, err)
	assert.ErrorIs(t, err, wallet.ErrInsufficientBalance)
}

func TestWallet_RefundStar_BeforeFirstSession(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletRefund", "Teacher")
	student := createStudentWithProfile(t, ctx, "WalletRefund", "Student", nil)
	admin := createTestUser(t, ctx, "admin", "Admin", "Refund")

	// Fund teacher wallet
	pkgs, _ := walletService.ListPackages(ctx)
	tx, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "REFUND-TEST-001",
	})
	walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "ok")

	// Create group series (no sessions added yet)
	series, _ := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
		Title:         "Refund Test Series",
		SessionType:   "group",
		DurationHours: 1,
		MaxStudents:   10,
	})

	// Enroll and accept
	enr, _ := seriesService.RequestToJoin(ctx, series.ID.String(), student.ID.String())
	seriesService.AcceptRequest(ctx, series.ID.String(), enr.ID.String(), teacher.ID.String())

	// Balance: 600 - 50 = 550
	w, _ := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 550.0, w.Balance)

	// Remove student BEFORE first session — should get refund
	err := seriesService.RemoveStudent(ctx, series.ID.String(), student.ID.String(), teacher.ID.String())
	require.NoError(t, err)

	// Balance: 550 + 50 = 600
	w, _ = walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 600.0, w.Balance)
	assert.Equal(t, 50.0, w.TotalRefunded)
}

func TestWallet_NoRefund_AfterFirstSession(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletNoRef", "Teacher")
	student := createStudentWithProfile(t, ctx, "WalletNoRef", "Student", nil)
	admin := createTestUser(t, ctx, "admin", "Admin", "NoRef")

	// Fund
	pkgs, _ := walletService.ListPackages(ctx)
	tx, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "NOREF-TEST-001",
	})
	walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "ok")

	// Create series + add a session
	series, _ := seriesService.CreateSeries(ctx, teacher.ID.String(), sessionseries.CreateSeriesRequest{
		Title:         "No Refund Series",
		SessionType:   "group",
		DurationHours: 1,
		MaxStudents:   10,
	})

	futureTime := time.Now().Add(24 * time.Hour).Format(time.RFC3339)
	seriesService.AddSessions(ctx, series.ID.String(), teacher.ID.String(), sessionseries.AddSessionsRequest{
		Sessions: []sessionseries.SessionDateInput{{StartTime: futureTime}},
	})

	// Enroll and accept
	enr, _ := seriesService.RequestToJoin(ctx, series.ID.String(), student.ID.String())
	seriesService.AcceptRequest(ctx, series.ID.String(), enr.ID.String(), teacher.ID.String())

	// Simulate first session started: mark a session in the series as 'live'
	_, err := testDB.Pool.Exec(ctx,
		`UPDATE sessions SET status = 'live', actual_start = NOW() WHERE series_id = $1 LIMIT 1`,
		series.ID,
	)
	// If LIMIT isn't supported in UPDATE, use subquery
	if err != nil {
		_, _ = testDB.Pool.Exec(ctx,
			`UPDATE sessions SET status = 'live', actual_start = NOW()
			 WHERE id = (SELECT id FROM sessions WHERE series_id = $1 LIMIT 1)`,
			series.ID,
		)
	}

	// Balance before remove: 600 - 50 = 550
	w, _ := walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 550.0, w.Balance)

	// Remove student after first session — NO refund
	seriesService.RemoveStudent(ctx, series.ID.String(), student.ID.String(), teacher.ID.String())

	// Balance should remain 550 (no refund)
	w, _ = walletService.GetOrCreateWallet(ctx, teacher.ID.String())
	assert.Equal(t, 550.0, w.Balance)
}

func TestWallet_TransactionHistory(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletHist", "Teacher")
	admin := createTestUser(t, ctx, "admin", "Admin", "Hist")

	// Buy two packages
	pkgs, _ := walletService.ListPackages(ctx)
	tx1, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "HIST-001",
	})
	walletService.AdminApprovePurchase(ctx, tx1.ID.String(), admin.ID.String(), true, "ok")

	tx2, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[1].ID,
		PaymentMethod: "edahabia",
		ProviderRef:   "HIST-002",
	})
	walletService.AdminApprovePurchase(ctx, tx2.ID.String(), admin.ID.String(), true, "ok")

	// List all transactions
	txs, total, err := walletService.ListTransactions(ctx, teacher.ID.String(), "", 1, 20)
	require.NoError(t, err)
	assert.Equal(t, int64(2), total)
	assert.Len(t, txs, 2)

	// Filter by type
	purchases, total, err := walletService.ListTransactions(ctx, teacher.ID.String(), "purchase", 1, 20)
	require.NoError(t, err)
	assert.Equal(t, int64(2), total)
	assert.Len(t, purchases, 2)
	assert.Equal(t, "purchase", purchases[0].Type)
}

func TestWallet_AdminListPendingPurchases(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletAdm", "Teacher")

	pkgs, _ := walletService.ListPackages(ctx)
	walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "ADMIN-PEND-001",
	})

	pending, total, err := walletService.AdminListPendingPurchases(ctx, 1, 50)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, total, int64(1))
	assert.GreaterOrEqual(t, len(pending), 1)

	// All should be pending
	for _, p := range pending {
		assert.Equal(t, "pending", p.Status)
		assert.Equal(t, "purchase", p.Type)
	}
}

func TestWallet_DoubleApprove_ReturnsError(t *testing.T) {
	ctx := context.Background()
	teacher := createTeacherWithProfile(t, ctx, "WalletDbl", "Teacher")
	admin := createTestUser(t, ctx, "admin", "Admin", "Dbl")

	pkgs, _ := walletService.ListPackages(ctx)
	tx, _ := walletService.BuyCredits(ctx, teacher.ID.String(), wallet.BuyCreditsRequest{
		PackageID:     pkgs[0].ID,
		PaymentMethod: "ccp_baridimob",
		ProviderRef:   "DBL-001",
	})

	// First approve succeeds
	_, err := walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "ok")
	require.NoError(t, err)

	// Second approve fails
	_, err = walletService.AdminApprovePurchase(ctx, tx.ID.String(), admin.ID.String(), true, "ok again")
	require.Error(t, err)
	assert.ErrorIs(t, err, wallet.ErrAlreadyProcessed)
}

// ═══════════════════════════════════════════════════════════════

func TestSummary(t *testing.T) {
	t.Log(`
═══════════════════════════════════════════════════════════════
                    TEST SUITE COVERAGE
═══════════════════════════════════════════════════════════════

✓ Suite 1: Teacher Availability Management
  - Set/Get/Update availability slots

✓ Suite 2: Teacher Offerings
  - Create/List/Update/Deactivate offerings

✓ Suite 3: Session Series Full Workflow
  - Create series, add sessions
  - Teacher invites students
  - Student requests to join
  - Accept/decline enrollments
  - Parent accepts for child
  - Browse available series
  - Remove student

✓ Suite 4: Booking Requests (Student & Parent)
  - Student creates booking
  - Parent creates booking for child
  - Cross-parent prevention
  - Teacher accepts/declines
  - List by role (teacher/parent/student)
  - Cancel booking
  - Time conflict detection
  - Availability checking

✓ Suite 5: Session Types (Individual vs Group)
  - One-on-one limits
  - Group capacity

✓ Suite 6: Edge Cases & Error Handling
  - Invalid UUIDs
  - Non-existent resources
  - Authorization checks
  - Duplicate requests

✓ Suite 7: Multi-Parent Multi-Child
  - Multiple parents with multiple children
  - Parent isolation
  - Cross-parent prevention

✓ Suite 8: Teacher Profile Operations
  - Get/Update profile

✓ Suite 9: Status Transitions
  - Booking status guards
  - Series status transitions

✓ Suite 10: Bug Fix Validations
  - Parent cancels own booking (booked_by_parent_id fix)
  - Student cannot cancel parent's booking (isolation)
  - Session participants UNIQUE constraint enforced
  - Message pagination with cursor (DESC + reverse fix)
  - Subject name_fr column used correctly

✓ Suite 11: Payment Status Guards
  - ConfirmPayment only on pending (ErrNotPending)
  - RefundPayment only on completed (ErrNotCompleted)
  - Cannot refund already refunded (ErrAlreadyRefunded)
  - Cannot confirm another user's transaction

✓ Suite 12: Teacher Wallet & Star System
  - Get/Create wallet (idempotent)
  - List credit packages (seeded data)
  - Buy credits → pending until admin approves
  - Admin rejects fake purchase
  - Star deducted on AcceptRequest (group: 50 DZD)
  - Star deducted on AcceptInvitation (private: 70 DZD)
  - Insufficient balance blocks acceptance
  - Refund star when student removed before 1st session
  - No refund after 1st session started
  - Transaction history listing & filtering
  - Admin list pending purchases
  - Double-approve returns ErrAlreadyProcessed

═══════════════════════════════════════════════════════════════
	`)
}
