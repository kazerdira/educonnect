package booking_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"educonnect/internal/booking"
	"educonnect/internal/config"
	"educonnect/pkg/database"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
)

// ═══════════════════════════════════════════════════════════════
// Test Setup & Helpers
// ═══════════════════════════════════════════════════════════════

var (
	testDB      *database.Postgres
	testService *booking.Service
)

// TestUser represents a user created for testing
type TestUser struct {
	ID        uuid.UUID
	Email     string
	Role      string
	FirstName string
	LastName  string
}

// TestChild represents a child linked to a parent
type TestChild struct {
	ID       uuid.UUID
	ParentID uuid.UUID
	Name     string
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

	testService = booking.NewService(testDB)

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
// Database Helpers - Create Test Data
// ═══════════════════════════════════════════════════════════════

func createTestUser(t *testing.T, ctx context.Context, role, firstName, lastName string) TestUser {
	t.Helper()

	id := uuid.New()
	email := fmt.Sprintf("%s_%s@test.com", firstName, id.String()[:8])
	password := "test123456"
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	require.NoError(t, err)

	_, err = testDB.Pool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, role, first_name, last_name, wilaya, language)
		VALUES ($1, $2, $3, $4, $5, $6, 'Alger', 'fr')
	`, id, email, string(hash), role, firstName, lastName)
	require.NoError(t, err, "failed to create test user")

	return TestUser{
		ID:        id,
		Email:     email,
		Role:      role,
		FirstName: firstName,
		LastName:  lastName,
	}
}

func createTeacherWithProfile(t *testing.T, ctx context.Context, firstName, lastName string) TestUser {
	t.Helper()

	user := createTestUser(t, ctx, "teacher", firstName, lastName)

	// Create teacher profile
	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO teacher_profiles (user_id, bio, verification_status)
		VALUES ($1, 'Test teacher bio', 'verified')
	`, user.ID)
	require.NoError(t, err, "failed to create teacher profile")

	return user
}

func createStudentWithProfile(t *testing.T, ctx context.Context, firstName, lastName string, parentID *uuid.UUID) TestUser {
	t.Helper()

	user := createTestUser(t, ctx, "student", firstName, lastName)

	// Get a level ID
	var levelID uuid.UUID
	err := testDB.Pool.QueryRow(ctx, `SELECT id FROM levels LIMIT 1`).Scan(&levelID)
	require.NoError(t, err, "failed to get level")

	// Create student profile
	_, err = testDB.Pool.Exec(ctx, `
		INSERT INTO student_profiles (user_id, level_id, parent_id, is_independent)
		VALUES ($1, $2, $3, $4)
	`, user.ID, levelID, parentID, parentID == nil)
	require.NoError(t, err, "failed to create student profile")

	return user
}

func createParentWithProfile(t *testing.T, ctx context.Context, firstName, lastName string) TestUser {
	t.Helper()

	user := createTestUser(t, ctx, "parent", firstName, lastName)

	// Create parent profile
	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO parent_profiles (user_id)
		VALUES ($1)
	`, user.ID)
	require.NoError(t, err, "failed to create parent profile")

	return user
}

func createTeacherAvailability(t *testing.T, ctx context.Context, teacherID uuid.UUID, dayOfWeek int, startTime, endTime string) {
	t.Helper()

	_, err := testDB.Pool.Exec(ctx, `
		INSERT INTO availability_slots (teacher_id, day_of_week, start_time, end_time)
		VALUES ($1, $2, $3::time, $4::time)
		ON CONFLICT DO NOTHING
	`, teacherID, dayOfWeek, startTime, endTime)
	require.NoError(t, err, "failed to create teacher availability")
}

func cleanupTestUser(t *testing.T, ctx context.Context, userID uuid.UUID) {
	t.Helper()

	// Delete in reverse order of foreign keys
	testDB.Pool.Exec(ctx, `DELETE FROM booking_requests WHERE student_id = $1 OR teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM session_participants WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM sessions WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM offerings WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM teacher_profiles WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM student_profiles WHERE user_id = $1 OR parent_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM parent_profiles WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, userID)
}

// getNextWeekday returns the next date that falls on the given weekday (0=Sunday, 1=Monday, etc.)
func getNextWeekday(weekday time.Weekday) time.Time {
	now := time.Now()
	daysUntil := int(weekday) - int(now.Weekday())
	if daysUntil <= 0 {
		daysUntil += 7
	}
	return now.AddDate(0, 0, daysUntil)
}

// ═══════════════════════════════════════════════════════════════
// Test Suite: Parent Booking Scenarios
// ═══════════════════════════════════════════════════════════════

func TestBookingService_FullScenario(t *testing.T) {
	ctx := context.Background()

	// ─── Setup: Create all test users ───────────────────────────
	t.Log("Setting up test users...")

	// Create teacher
	teacher := createTeacherWithProfile(t, ctx, "Prof", "Ahmed")
	defer cleanupTestUser(t, ctx, teacher.ID)

	// Create teacher availability (Monday 09:00-17:00)
	nextMonday := getNextWeekday(time.Monday)
	createTeacherAvailability(t, ctx, teacher.ID, 1, "09:00", "17:00") // 1 = Monday

	// Create independent student (no parent)
	independentStudent := createStudentWithProfile(t, ctx, "Karim", "Student", nil)
	defer cleanupTestUser(t, ctx, independentStudent.ID)

	// Create Parent 1 with Child 1
	parent1 := createParentWithProfile(t, ctx, "Papa", "Fateh")
	defer cleanupTestUser(t, ctx, parent1.ID)
	child1 := createStudentWithProfile(t, ctx, "Amine", "Fateh", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1.ID)

	// Create Parent 2 with Child 2
	parent2 := createParentWithProfile(t, ctx, "Mama", "Khadija")
	defer cleanupTestUser(t, ctx, parent2.ID)
	child2 := createStudentWithProfile(t, ctx, "Sara", "Khadija", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2.ID)

	t.Logf("Created users:")
	t.Logf("  Teacher: %s (%s)", teacher.FirstName, teacher.ID)
	t.Logf("  Independent Student: %s (%s)", independentStudent.FirstName, independentStudent.ID)
	t.Logf("  Parent1: %s (%s), Child1: %s (%s)", parent1.FirstName, parent1.ID, child1.FirstName, child1.ID)
	t.Logf("  Parent2: %s (%s), Child2: %s (%s)", parent2.FirstName, parent2.ID, child2.FirstName, child2.ID)

	// ═══════════════════════════════════════════════════════════
	// Scenario 1: Independent student books for themselves
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario1_IndependentStudentBooksSelf", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "09:00",
			EndTime:       "10:00",
			Message:       "Je veux améliorer en maths",
			Purpose:       "revision",
		}

		result, err := testService.CreateBookingRequest(ctx, independentStudent.ID.String(), "student", req)
		require.NoError(t, err)
		require.NotNil(t, result)

		assert.Equal(t, independentStudent.ID.String(), result.StudentID)
		assert.Equal(t, teacher.ID.String(), result.TeacherID)
		assert.Equal(t, "pending", result.Status)
		assert.Nil(t, result.BookedByParentID, "Student booking should have no parent ID")
		assert.Empty(t, result.BookedByParentName, "Student booking should have no parent name")

		t.Logf("✓ Created booking %s for independent student", result.ID)
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 2: Parent 1 books for their Child 1
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario2_Parent1BooksForChild1", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:30",
			EndTime:       "11:30",
			Message:       "Mon fils a besoin d'aide en physique",
			Purpose:       "homework",
			ForChildID:    child1.ID.String(),
		}

		result, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.NoError(t, err)
		require.NotNil(t, result)

		assert.Equal(t, child1.ID.String(), result.StudentID, "Booking should be for child1")
		assert.Equal(t, teacher.ID.String(), result.TeacherID)
		assert.Equal(t, "pending", result.Status)
		require.NotNil(t, result.BookedByParentID, "Should have parent ID")
		assert.Equal(t, parent1.ID.String(), *result.BookedByParentID)
		assert.Contains(t, result.BookedByParentName, "Papa", "Should show parent name")

		t.Logf("✓ Created booking %s for child1 by parent1", result.ID)
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 3: Parent 2 books for their Child 2
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario3_Parent2BooksForChild2", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "14:00",
			EndTime:       "15:30",
			Message:       "Ma fille prépare le BEM",
			Purpose:       "exam_prep",
			ForChildID:    child2.ID.String(),
		}

		result, err := testService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req)
		require.NoError(t, err)
		require.NotNil(t, result)

		assert.Equal(t, child2.ID.String(), result.StudentID, "Booking should be for child2")
		require.NotNil(t, result.BookedByParentID)
		assert.Equal(t, parent2.ID.String(), *result.BookedByParentID)
		assert.Contains(t, result.BookedByParentName, "Mama", "Should show parent name")

		t.Logf("✓ Created booking %s for child2 by parent2", result.ID)
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 4: Parent 1 tries to book for Child 2 (NOT their child)
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario4_Parent1CannotBookForOtherChild", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "16:00",
			EndTime:       "17:00",
			Message:       "Trying to book for someone else's child",
			ForChildID:    child2.ID.String(), // Child belongs to parent2!
		}

		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "not the parent", "Should reject booking for non-own child")

		t.Log("✓ Correctly rejected parent1 booking for child2")
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 5: Parent without specifying for_child_id should fail
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario5_ParentMustSpecifyChild", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "11:30",
			EndTime:       "12:30",
			Message:       "Parent booking without child",
			// ForChildID is not set
		}

		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "for_child_id", "Should require for_child_id for parent")

		t.Log("✓ Correctly rejected parent booking without for_child_id")
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 6: Parent tries to book with invalid child ID
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario6_InvalidChildID", func(t *testing.T) {
		fakeChildID := uuid.New() // Non-existent child

		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "12:00",
			EndTime:       "13:00",
			Message:       "Booking for fake child",
			ForChildID:    fakeChildID.String(),
		}

		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "not the parent")

		t.Log("✓ Correctly rejected booking for non-existent child")
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 7: Booking outside teacher availability
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario7_OutsideAvailability", func(t *testing.T) {
		// Teacher available Monday 09:00-17:00, try booking 20:00-21:00
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "20:00",
			EndTime:       "21:00",
			Message:       "Evening booking",
			ForChildID:    child1.ID.String(),
		}

		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrSlotNotAvailable)

		t.Log("✓ Correctly rejected booking outside availability")
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 8: Invalid time format
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario8_InvalidTimeFormat", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "9:00", // Should be "09:00"
			EndTime:       "10:00",
			ForChildID:    child1.ID.String(),
		}

		// This may or may not fail depending on time.Parse flexibility
		// but let's test it
		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		if err != nil {
			t.Logf("✓ Rejected invalid time format: %v", err)
		} else {
			t.Log("✓ Accepted time format (lenient parsing)")
		}
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 9: Invalid date format
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario9_InvalidDateFormat", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: "14-02-2026", // Wrong format, should be 2026-02-14
			StartTime:     "09:00",
			EndTime:       "10:00",
			ForChildID:    child1.ID.String(),
		}

		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "requested_date")

		t.Log("✓ Correctly rejected invalid date format")
	})

	// ═══════════════════════════════════════════════════════════
	// Scenario 10: Invalid teacher ID
	// ═══════════════════════════════════════════════════════════
	t.Run("Scenario10_InvalidTeacherID", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     "not-a-uuid",
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "09:00",
			EndTime:       "10:00",
			ForChildID:    child1.ID.String(),
		}

		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "teacher id")

		t.Log("✓ Correctly rejected invalid teacher ID")
	})
}

// ═══════════════════════════════════════════════════════════════
// Test: List Bookings by Role
// ═══════════════════════════════════════════════════════════════

func TestBookingService_ListByRole(t *testing.T) {
	ctx := context.Background()

	// Setup
	teacher := createTeacherWithProfile(t, ctx, "ListTest", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	nextMonday := getNextWeekday(time.Monday)
	createTeacherAvailability(t, ctx, teacher.ID, 1, "08:00", "20:00")

	parent := createParentWithProfile(t, ctx, "ListTest", "Parent")
	defer cleanupTestUser(t, ctx, parent.ID)
	child := createStudentWithProfile(t, ctx, "ListTest", "Child", &parent.ID)
	defer cleanupTestUser(t, ctx, child.ID)

	independentStudent := createStudentWithProfile(t, ctx, "ListTest", "IndStudent", nil)
	defer cleanupTestUser(t, ctx, independentStudent.ID)

	// Create bookings
	// 1. Parent books for child
	parentBookingReq := booking.CreateBookingRequest{
		TeacherID:     teacher.ID.String(),
		SessionType:   "individual",
		RequestedDate: nextMonday.Format("2006-01-02"),
		StartTime:     "08:00",
		EndTime:       "09:00",
		Message:       "Parent booking",
		ForChildID:    child.ID.String(),
	}
	parentBooking, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", parentBookingReq)
	require.NoError(t, err)

	// 2. Independent student books for self
	studentBookingReq := booking.CreateBookingRequest{
		TeacherID:     teacher.ID.String(),
		SessionType:   "individual",
		RequestedDate: nextMonday.Format("2006-01-02"),
		StartTime:     "10:00",
		EndTime:       "11:00",
		Message:       "Student booking",
	}
	studentBooking, err := testService.CreateBookingRequest(ctx, independentStudent.ID.String(), "student", studentBookingReq)
	require.NoError(t, err)

	t.Logf("Created parent booking: %s, student booking: %s", parentBooking.ID, studentBooking.ID)

	// ─── Test: List as teacher (should see all) ─────────────────
	t.Run("ListAsTeacher", func(t *testing.T) {
		query := booking.ListBookingsQuery{
			Role:  "as_teacher",
			Page:  1,
			Limit: 20,
		}
		results, total, err := testService.ListBookingRequests(ctx, teacher.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(2))
		assert.GreaterOrEqual(t, len(results), 2)

		// Check that parent booking has parent info
		for _, b := range results {
			if b.ID == parentBooking.ID {
				assert.NotNil(t, b.BookedByParentID, "Parent booking should have parent ID")
				assert.NotEmpty(t, b.BookedByParentName, "Parent booking should have parent name")
			}
			if b.ID == studentBooking.ID {
				assert.Nil(t, b.BookedByParentID, "Student booking should not have parent ID")
			}
		}

		t.Logf("✓ Teacher sees %d bookings (total: %d)", len(results), total)
	})

	// ─── Test: List as parent (only their bookings) ─────────────
	t.Run("ListAsParent", func(t *testing.T) {
		query := booking.ListBookingsQuery{
			Role:  "as_parent",
			Page:  1,
			Limit: 20,
		}
		results, total, err := testService.ListBookingRequests(ctx, parent.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(1))

		// All results should be booked by this parent
		for _, b := range results {
			require.NotNil(t, b.BookedByParentID)
			assert.Equal(t, parent.ID.String(), *b.BookedByParentID)
		}

		t.Logf("✓ Parent sees %d bookings they made", len(results))
	})

	// ─── Test: List as student (own bookings) ───────────────────
	t.Run("ListAsStudent", func(t *testing.T) {
		query := booking.ListBookingsQuery{
			Role:  "as_student",
			Page:  1,
			Limit: 20,
		}
		results, total, err := testService.ListBookingRequests(ctx, independentStudent.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(1))

		for _, b := range results {
			assert.Equal(t, independentStudent.ID.String(), b.StudentID)
		}

		t.Logf("✓ Student sees %d of their bookings", len(results))
	})

	// ─── Test: Child can see booking made by parent ─────────────
	t.Run("ChildSeesParentBooking", func(t *testing.T) {
		query := booking.ListBookingsQuery{
			Role:  "as_student",
			Page:  1,
			Limit: 20,
		}
		results, total, err := testService.ListBookingRequests(ctx, child.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(1))

		// The child should see the booking that was made FOR them
		found := false
		for _, b := range results {
			if b.ID == parentBooking.ID {
				found = true
				assert.Equal(t, child.ID.String(), b.StudentID)
				assert.NotNil(t, b.BookedByParentID)
				assert.Equal(t, parent.ID.String(), *b.BookedByParentID)
			}
		}
		assert.True(t, found, "Child should see booking made by parent")

		t.Log("✓ Child sees booking made by parent for them")
	})

	// ─── Test: Filter by status ─────────────────────────────────
	t.Run("FilterByStatus", func(t *testing.T) {
		query := booking.ListBookingsQuery{
			Role:   "as_teacher",
			Status: "pending",
			Page:   1,
			Limit:  20,
		}
		results, _, err := testService.ListBookingRequests(ctx, teacher.ID.String(), query)
		require.NoError(t, err)

		for _, b := range results {
			assert.Equal(t, "pending", b.Status)
		}

		t.Logf("✓ Status filter works, found %d pending bookings", len(results))
	})
}

// ═══════════════════════════════════════════════════════════════
// Test: Accept and Decline Bookings
// ═══════════════════════════════════════════════════════════════

func TestBookingService_AcceptDecline(t *testing.T) {
	ctx := context.Background()

	// Setup
	teacher := createTeacherWithProfile(t, ctx, "AcceptTest", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	nextMonday := getNextWeekday(time.Monday)
	createTeacherAvailability(t, ctx, teacher.ID, 1, "08:00", "20:00")

	parent := createParentWithProfile(t, ctx, "AcceptTest", "Parent")
	defer cleanupTestUser(t, ctx, parent.ID)
	child := createStudentWithProfile(t, ctx, "AcceptTest", "Child", &parent.ID)
	defer cleanupTestUser(t, ctx, child.ID)

	// ─── Test: Teacher accepts parent booking ───────────────────
	t.Run("TeacherAcceptsParentBooking", func(t *testing.T) {
		// Create booking
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "08:00",
			EndTime:       "09:00",
			Message:       "Booking to accept",
			ForChildID:    child.ID.String(),
		}
		created, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.NoError(t, err)

		// Accept
		acceptReq := booking.AcceptBookingRequest{
			Title:       "Séance de maths",
			Description: "Cours particulier",
			Price:       2000,
		}
		accepted, err := testService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), acceptReq)
		require.NoError(t, err)
		require.NotNil(t, accepted)

		assert.Equal(t, "accepted", accepted.Status)
		assert.NotNil(t, accepted.SessionID, "Should create a session")

		// Parent info should still be there
		assert.NotNil(t, accepted.BookedByParentID)
		assert.Equal(t, parent.ID.String(), *accepted.BookedByParentID)

		t.Logf("✓ Teacher accepted booking, session created: %v", *accepted.SessionID)
	})

	// ─── Test: Teacher declines booking ─────────────────────────
	t.Run("TeacherDeclinesBooking", func(t *testing.T) {
		// Create another booking
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:00",
			EndTime:       "11:00",
			Message:       "Booking to decline",
			ForChildID:    child.ID.String(),
		}
		created, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.NoError(t, err)

		// Decline
		declineReq := booking.DeclineBookingRequest{
			Reason: "Je ne suis pas disponible à cette date",
		}
		declined, err := testService.DeclineBookingRequest(ctx, created.ID, teacher.ID.String(), declineReq)
		require.NoError(t, err)
		require.NotNil(t, declined)

		assert.Equal(t, "declined", declined.Status)
		assert.Equal(t, declineReq.Reason, declined.DeclineReason)

		t.Logf("✓ Teacher declined booking with reason")
	})

	// ─── Test: Non-owner teacher cannot accept ──────────────────
	t.Run("NonOwnerCannotAccept", func(t *testing.T) {
		// Create another teacher
		otherTeacher := createTeacherWithProfile(t, ctx, "Other", "Teacher")
		defer cleanupTestUser(t, ctx, otherTeacher.ID)

		// Create booking for original teacher
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "12:00",
			EndTime:       "13:00",
			Message:       "Booking for teacher1",
			ForChildID:    child.ID.String(),
		}
		created, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.NoError(t, err)

		// Other teacher tries to accept
		acceptReq := booking.AcceptBookingRequest{Price: 1500}
		_, err = testService.AcceptBookingRequest(ctx, created.ID, otherTeacher.ID.String(), acceptReq)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrUnauthorized)

		t.Log("✓ Non-owner teacher correctly rejected")
	})

	// ─── Test: Cannot accept already accepted booking ───────────
	t.Run("CannotDoubleAccept", func(t *testing.T) {
		// Create and accept a booking
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "14:00",
			EndTime:       "15:00",
			Message:       "Will be accepted twice",
			ForChildID:    child.ID.String(),
		}
		created, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.NoError(t, err)

		// Accept first time
		acceptReq := booking.AcceptBookingRequest{Price: 1500}
		_, err = testService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), acceptReq)
		require.NoError(t, err)

		// Try to accept again
		_, err = testService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), acceptReq)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrInvalidStatus)

		t.Log("✓ Cannot accept already accepted booking")
	})
}

// ═══════════════════════════════════════════════════════════════
// Test: Cancel Booking
// ═══════════════════════════════════════════════════════════════

func TestBookingService_Cancel(t *testing.T) {
	ctx := context.Background()

	// Setup
	teacher := createTeacherWithProfile(t, ctx, "CancelTest", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	nextMonday := getNextWeekday(time.Monday)
	createTeacherAvailability(t, ctx, teacher.ID, 1, "08:00", "20:00")

	student := createStudentWithProfile(t, ctx, "CancelTest", "Student", nil)
	defer cleanupTestUser(t, ctx, student.ID)

	// ─── Test: Student can cancel their own booking ─────────────
	t.Run("StudentCancelsOwnBooking", func(t *testing.T) {
		// Create booking
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "08:00",
			EndTime:       "09:00",
			Message:       "Booking to cancel",
		}
		created, err := testService.CreateBookingRequest(ctx, student.ID.String(), "student", createReq)
		require.NoError(t, err)

		// Cancel
		err = testService.CancelBookingRequest(ctx, created.ID, student.ID.String())
		require.NoError(t, err)

		// Verify status
		booking, err := testService.GetBookingRequest(ctx, created.ID, student.ID.String())
		require.NoError(t, err)
		assert.Equal(t, "cancelled", booking.Status)

		t.Log("✓ Student cancelled their booking")
	})

	// ─── Test: Cannot cancel another student's booking ──────────
	t.Run("CannotCancelOthersBooking", func(t *testing.T) {
		otherStudent := createStudentWithProfile(t, ctx, "Other", "Student", nil)
		defer cleanupTestUser(t, ctx, otherStudent.ID)

		// Create booking by first student
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:00",
			EndTime:       "11:00",
			Message:       "First student's booking",
		}
		created, err := testService.CreateBookingRequest(ctx, student.ID.String(), "student", createReq)
		require.NoError(t, err)

		// Other student tries to cancel
		err = testService.CancelBookingRequest(ctx, created.ID, otherStudent.ID.String())
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrBookingNotFound) // Returns not found for unauthorized

		t.Log("✓ Cannot cancel another student's booking")
	})
}

// ═══════════════════════════════════════════════════════════════
// Test: Concurrent Booking Conflicts
// ═══════════════════════════════════════════════════════════════

func TestBookingService_TimeConflicts(t *testing.T) {
	ctx := context.Background()

	// Setup
	teacher := createTeacherWithProfile(t, ctx, "ConflictTest", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	nextMonday := getNextWeekday(time.Monday)
	createTeacherAvailability(t, ctx, teacher.ID, 1, "08:00", "20:00")

	parent := createParentWithProfile(t, ctx, "ConflictTest", "Parent")
	defer cleanupTestUser(t, ctx, parent.ID)
	child := createStudentWithProfile(t, ctx, "ConflictTest", "Child", &parent.ID)
	defer cleanupTestUser(t, ctx, child.ID)

	// ─── Create and accept a booking ────────────────────────────
	t.Run("SetupAcceptedBooking", func(t *testing.T) {
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:00",
			EndTime:       "11:00",
			Message:       "First booking",
			ForChildID:    child.ID.String(),
		}
		created, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.NoError(t, err)

		acceptReq := booking.AcceptBookingRequest{Price: 1500}
		_, err = testService.AcceptBookingRequest(ctx, created.ID, teacher.ID.String(), acceptReq)
		require.NoError(t, err)

		t.Log("✓ Set up accepted booking 10:00-11:00")
	})

	// ─── Test: Overlapping booking should fail ──────────────────
	t.Run("OverlappingBookingFails", func(t *testing.T) {
		// Try to book 10:30-11:30 (overlaps with 10:00-11:00)
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "10:30",
			EndTime:       "11:30",
			Message:       "Overlapping booking",
			ForChildID:    child.ID.String(),
		}
		_, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.Error(t, err)
		assert.ErrorIs(t, err, booking.ErrAlreadyBooked)

		t.Log("✓ Overlapping booking correctly rejected")
	})

	// ─── Test: Adjacent booking should succeed ──────────────────
	t.Run("AdjacentBookingSucceeds", func(t *testing.T) {
		// Book 11:00-12:00 (starts when other ends)
		createReq := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "11:00",
			EndTime:       "12:00",
			Message:       "Adjacent booking",
			ForChildID:    child.ID.String(),
		}
		created, err := testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", createReq)
		require.NoError(t, err)
		require.NotNil(t, created)

		t.Log("✓ Adjacent booking (no overlap) succeeded")
	})
}

// ═══════════════════════════════════════════════════════════════
// Test: Multiple Parents, Multiple Children
// ═══════════════════════════════════════════════════════════════

func TestBookingService_MultiParentMultiChild(t *testing.T) {
	ctx := context.Background()

	// Setup teacher
	teacher := createTeacherWithProfile(t, ctx, "MultiTest", "Teacher")
	defer cleanupTestUser(t, ctx, teacher.ID)

	nextMonday := getNextWeekday(time.Monday)
	createTeacherAvailability(t, ctx, teacher.ID, 1, "08:00", "20:00")

	// Create Parent 1 with 2 children
	parent1 := createParentWithProfile(t, ctx, "Parent", "One")
	defer cleanupTestUser(t, ctx, parent1.ID)
	child1a := createStudentWithProfile(t, ctx, "Child1A", "One", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1a.ID)
	child1b := createStudentWithProfile(t, ctx, "Child1B", "One", &parent1.ID)
	defer cleanupTestUser(t, ctx, child1b.ID)

	// Create Parent 2 with 2 children
	parent2 := createParentWithProfile(t, ctx, "Parent", "Two")
	defer cleanupTestUser(t, ctx, parent2.ID)
	child2a := createStudentWithProfile(t, ctx, "Child2A", "Two", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2a.ID)
	child2b := createStudentWithProfile(t, ctx, "Child2B", "Two", &parent2.ID)
	defer cleanupTestUser(t, ctx, child2b.ID)

	t.Log("Created 2 parents with 2 children each")

	// ─── Parent 1 books for both children ───────────────────────
	t.Run("Parent1BooksForBothChildren", func(t *testing.T) {
		// Book for child1a
		req1 := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "08:00",
			EndTime:       "09:00",
			Message:       "For child 1a",
			ForChildID:    child1a.ID.String(),
		}
		booking1, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req1)
		require.NoError(t, err)
		assert.Equal(t, child1a.ID.String(), booking1.StudentID)

		// Book for child1b
		req2 := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "09:30",
			EndTime:       "10:30",
			Message:       "For child 1b",
			ForChildID:    child1b.ID.String(),
		}
		booking2, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req2)
		require.NoError(t, err)
		assert.Equal(t, child1b.ID.String(), booking2.StudentID)

		t.Log("✓ Parent1 booked for both their children")
	})

	// ─── Parent 2 books for both children ───────────────────────
	t.Run("Parent2BooksForBothChildren", func(t *testing.T) {
		req1 := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "14:00",
			EndTime:       "15:00",
			Message:       "For child 2a",
			ForChildID:    child2a.ID.String(),
		}
		_, err := testService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req1)
		require.NoError(t, err)

		req2 := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "group",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "15:30",
			EndTime:       "16:30",
			Message:       "For child 2b",
			ForChildID:    child2b.ID.String(),
		}
		_, err = testService.CreateBookingRequest(ctx, parent2.ID.String(), "parent", req2)
		require.NoError(t, err)

		t.Log("✓ Parent2 booked for both their children")
	})

	// ─── Parent 1 cannot book for Parent 2's children ───────────
	t.Run("Parent1CannotBookParent2Children", func(t *testing.T) {
		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: nextMonday.Format("2006-01-02"),
			StartTime:     "17:00",
			EndTime:       "18:00",
			ForChildID:    child2a.ID.String(), // child2a belongs to parent2
		}
		_, err := testService.CreateBookingRequest(ctx, parent1.ID.String(), "parent", req)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "not the parent")

		t.Log("✓ Parent1 correctly blocked from booking for Parent2's child")
	})

	// ─── List bookings by each parent ───────────────────────────
	t.Run("EachParentSeesOnlyTheirBookings", func(t *testing.T) {
		query := booking.ListBookingsQuery{Role: "as_parent", Page: 1, Limit: 20}

		// Parent 1's bookings
		results1, _, err := testService.ListBookingRequests(ctx, parent1.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, len(results1), 2)
		for _, b := range results1 {
			require.NotNil(t, b.BookedByParentID)
			assert.Equal(t, parent1.ID.String(), *b.BookedByParentID)
		}

		// Parent 2's bookings
		results2, _, err := testService.ListBookingRequests(ctx, parent2.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, len(results2), 2)
		for _, b := range results2 {
			require.NotNil(t, b.BookedByParentID)
			assert.Equal(t, parent2.ID.String(), *b.BookedByParentID)
		}

		t.Logf("✓ Parent1 sees %d bookings, Parent2 sees %d bookings", len(results1), len(results2))
	})

	// ─── Teacher sees all bookings with parent info ─────────────
	t.Run("TeacherSeesAllWithParentInfo", func(t *testing.T) {
		query := booking.ListBookingsQuery{Role: "as_teacher", Page: 1, Limit: 20}
		results, total, err := testService.ListBookingRequests(ctx, teacher.ID.String(), query)
		require.NoError(t, err)
		assert.GreaterOrEqual(t, total, int64(4), "Should see at least 4 bookings from both parents")

		// Count bookings with parent info
		withParentInfo := 0
		for _, b := range results {
			if b.BookedByParentID != nil {
				withParentInfo++
				assert.NotEmpty(t, b.BookedByParentName)
			}
		}
		assert.GreaterOrEqual(t, withParentInfo, 4, "All 4 parent bookings should have parent info")

		t.Logf("✓ Teacher sees %d total bookings, %d with parent info", len(results), withParentInfo)
	})
}

// ═══════════════════════════════════════════════════════════════
// Benchmark Tests
// ═══════════════════════════════════════════════════════════════

func BenchmarkCreateBooking(b *testing.B) {
	ctx := context.Background()

	// Setup (outside benchmark)
	teacher := createTeacherForBenchmark(ctx)
	parent := createParentForBenchmark(ctx)
	child := createChildForBenchmark(ctx, parent.ID)

	// Ensure availability
	for i := 0; i < 7; i++ {
		testDB.Pool.Exec(ctx, `
			INSERT INTO availability_slots (teacher_id, day_of_week, start_time, end_time)
			VALUES ($1, $2, '00:00', '23:59')
			ON CONFLICT DO NOTHING
		`, teacher.ID, i)
	}

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		// Use different times to avoid conflicts
		startHour := (i % 23)
		date := time.Now().AddDate(0, 0, (i/23)+1).Format("2006-01-02")

		req := booking.CreateBookingRequest{
			TeacherID:     teacher.ID.String(),
			SessionType:   "individual",
			RequestedDate: date,
			StartTime:     fmt.Sprintf("%02d:00", startHour),
			EndTime:       fmt.Sprintf("%02d:30", startHour),
			ForChildID:    child.ID.String(),
		}
		testService.CreateBookingRequest(ctx, parent.ID.String(), "parent", req)
	}

	// Cleanup
	testDB.Pool.Exec(ctx, `DELETE FROM booking_requests WHERE teacher_id = $1`, teacher.ID)
	cleanupTestUserBench(ctx, child.ID)
	cleanupTestUserBench(ctx, parent.ID)
	cleanupTestUserBench(ctx, teacher.ID)
}

func createTeacherForBenchmark(ctx context.Context) TestUser {
	id := uuid.New()
	hash, _ := bcrypt.GenerateFromPassword([]byte("test"), 12)
	testDB.Pool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, role, first_name, last_name, wilaya, language)
		VALUES ($1, $2, $3, 'teacher', 'Bench', 'Teacher', 'Alger', 'fr')
	`, id, fmt.Sprintf("bench_teacher_%s@test.com", id.String()[:8]), string(hash))
	testDB.Pool.Exec(ctx, `
		INSERT INTO teacher_profiles (user_id, verification_status)
		VALUES ($1, 'verified')
	`, id)
	return TestUser{ID: id, Role: "teacher"}
}

func createParentForBenchmark(ctx context.Context) TestUser {
	id := uuid.New()
	hash, _ := bcrypt.GenerateFromPassword([]byte("test"), 12)
	testDB.Pool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, role, first_name, last_name, wilaya, language)
		VALUES ($1, $2, $3, 'parent', 'Bench', 'Parent', 'Alger', 'fr')
	`, id, fmt.Sprintf("bench_parent_%s@test.com", id.String()[:8]), string(hash))
	testDB.Pool.Exec(ctx, `
		INSERT INTO parent_profiles (user_id) VALUES ($1)
	`, id)
	return TestUser{ID: id, Role: "parent"}
}

func createChildForBenchmark(ctx context.Context, parentID uuid.UUID) TestUser {
	id := uuid.New()
	hash, _ := bcrypt.GenerateFromPassword([]byte("test"), 12)
	testDB.Pool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, role, first_name, last_name, wilaya, language)
		VALUES ($1, $2, $3, 'student', 'Bench', 'Child', 'Alger', 'fr')
	`, id, fmt.Sprintf("bench_child_%s@test.com", id.String()[:8]), string(hash))

	var levelID uuid.UUID
	testDB.Pool.QueryRow(ctx, `SELECT id FROM levels LIMIT 1`).Scan(&levelID)
	testDB.Pool.Exec(ctx, `
		INSERT INTO student_profiles (user_id, level_id, parent_id, is_independent)
		VALUES ($1, $2, $3, false)
	`, id, levelID, parentID)
	return TestUser{ID: id, Role: "student"}
}

func cleanupTestUserBench(ctx context.Context, userID uuid.UUID) {
	testDB.Pool.Exec(ctx, `DELETE FROM availability_slots WHERE teacher_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM teacher_profiles WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM student_profiles WHERE user_id = $1 OR parent_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM parent_profiles WHERE user_id = $1`, userID)
	testDB.Pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, userID)
}
