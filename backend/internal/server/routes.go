package server

import (
	"net/http"

	"educonnect/internal/middleware"

	"github.com/gin-gonic/gin"
)

// setupRoutes registers all API route groups.
func (s *Server) setupRoutes() {
	// ── Global middleware ────────────────────────────────────────
	s.router.Use(
		middleware.Logger(),
		middleware.CORS(),
		gin.Recovery(),
	)

	// ── Health check ────────────────────────────────────────────
	s.router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "educonnect-api",
			"version": "1.0.0",
		})
	})

	// ── API v1 ──────────────────────────────────────────────────
	v1 := s.router.Group("/api/v1")

	// ── Auth routes (public) ────────────────────────────────────
	auth := v1.Group("/auth")
	{
		auth.POST("/register/teacher", s.handleRegisterTeacher())
		auth.POST("/register/parent", s.handleRegisterParent())
		auth.POST("/register/student", s.handleRegisterStudent())
		auth.POST("/login", s.handleLogin())
		auth.POST("/login/phone", s.handlePhoneLogin())
		auth.POST("/verify-otp", s.handleVerifyOTP())
		auth.POST("/refresh", s.handleRefreshToken())
		auth.POST("/forgot-password", s.handleForgotPassword())
		auth.POST("/reset-password", s.handleResetPassword())
	}

	// ── Lookup routes (public) ───────────────────────────────────
	v1.GET("/levels", s.handleGetLevels())
	v1.GET("/subjects", s.handleGetSubjects())

	// ── Protected routes ────────────────────────────────────────
	protected := v1.Group("")
	protected.Use(middleware.Auth(s.deps.Config.JWT.Secret))

	// ── User routes ─────────────────────────────────────────────
	users := protected.Group("/users")
	{
		users.GET("/me", s.handleGetProfile())
		users.PUT("/me", s.handleUpdateProfile())
		users.PUT("/me/avatar", s.handleUploadAvatar())
		users.PUT("/me/password", s.handleChangePassword())
		users.DELETE("/me", s.handleDeactivateAccount())
	}

	// ── Teacher routes ──────────────────────────────────────────
	teachers := protected.Group("/teachers")
	{
		teachers.GET("", s.handleListTeachers())   // search & list
		teachers.GET("/:id", s.handleGetTeacher()) // public profile
		teachers.PUT("/profile", s.handleUpdateTeacherProfile())
		teachers.GET("/dashboard", s.handleTeacherDashboard())

		// Offerings
		teachers.POST("/offerings", s.handleCreateOffering())
		teachers.GET("/offerings", s.handleListOfferings())
		teachers.PUT("/offerings/:id", s.handleUpdateOffering())
		teachers.DELETE("/offerings/:id", s.handleDeleteOffering())

		// Availability
		teachers.PUT("/availability", s.handleSetAvailability())
		teachers.GET("/:id/availability", s.handleGetAvailability())

		// Earnings
		teachers.GET("/earnings", s.handleGetEarnings())
		teachers.POST("/payouts", s.handleRequestPayout())
	}

	// ── Student routes ──────────────────────────────────────────
	students := protected.Group("/students")
	{
		students.GET("/dashboard", s.handleStudentDashboard())
		students.GET("/progress", s.handleStudentProgress())
		students.GET("/enrollments", s.handleStudentEnrollments())
	}

	// ── Parent routes ───────────────────────────────────────────
	parents := protected.Group("/parents")
	{
		parents.POST("/children", s.handleAddChild())
		parents.GET("/children", s.handleListChildren())
		parents.PUT("/children/:childId", s.handleUpdateChild())
		parents.DELETE("/children/:childId", s.handleRemoveChild())
		parents.GET("/children/:childId/progress", s.handleChildProgress())
		parents.GET("/dashboard", s.handleParentDashboard())
	}

	// ── Session routes ──────────────────────────────────────────
	sessions := protected.Group("/sessions")
	{
		sessions.POST("", s.handleCreateSession())
		sessions.GET("", s.handleListSessions())
		sessions.GET("/:id", s.handleGetSession())
		sessions.POST("/:id/join", s.handleJoinSession())
		sessions.POST("/:id/cancel", s.handleCancelSession())
		sessions.PUT("/:id/reschedule", s.handleRescheduleSession())
		sessions.POST("/:id/end", s.handleEndSession())
		sessions.GET("/:id/recording", s.handleGetRecording())
	}

	// ── Course routes ───────────────────────────────────────────
	courses := protected.Group("/courses")
	{
		courses.POST("", s.handleCreateCourse())
		courses.GET("", s.handleListCourses())
		courses.GET("/:id", s.handleGetCourse())
		courses.PUT("/:id", s.handleUpdateCourse())
		courses.DELETE("/:id", s.handleDeleteCourse())

		// Chapters & lessons
		courses.POST("/:id/chapters", s.handleCreateChapter())
		courses.POST("/:id/chapters/:chapterId/lessons", s.handleCreateLesson())
		courses.POST("/:id/lessons/:lessonId/upload", s.handleUploadVideo())
		courses.POST("/:id/enroll", s.handleEnrollCourse())
	}

	// ── Homework routes ─────────────────────────────────────────
	homework := protected.Group("/homework")
	{
		homework.POST("", s.handleCreateHomework())
		homework.GET("", s.handleListHomework())
		homework.GET("/:id", s.handleGetHomework())
		homework.POST("/:id/submit", s.handleSubmitHomework())
		homework.PUT("/submissions/:id/grade", s.handleGradeHomework())
	}

	// ── Quiz routes ─────────────────────────────────────────────
	quizzes := protected.Group("/quizzes")
	{
		quizzes.POST("", s.handleCreateQuiz())
		quizzes.GET("", s.handleListQuizzes())
		quizzes.GET("/:id", s.handleGetQuiz())
		quizzes.POST("/:id/attempt", s.handleAttemptQuiz())
		quizzes.GET("/:id/results", s.handleQuizResults())
	}

	// ── Payment routes ──────────────────────────────────────────
	payments := protected.Group("/payments")
	{
		payments.POST("/initiate", s.handleInitiatePayment())
		payments.POST("/confirm", s.handleConfirmPayment())
		payments.GET("/history", s.handlePaymentHistory())
		payments.POST("/refund", s.handleRefundPayment())
	}

	// ── Subscription routes ─────────────────────────────────────
	subscriptions := protected.Group("/subscriptions")
	{
		subscriptions.POST("", s.handleCreateSubscription())
		subscriptions.GET("", s.handleListSubscriptions())
		subscriptions.DELETE("/:id", s.handleCancelSubscription())
	}

	// ── Review routes ───────────────────────────────────────────
	reviews := protected.Group("/reviews")
	{
		reviews.POST("", s.handleCreateReview())
		reviews.GET("/teacher/:id", s.handleGetTeacherReviews())
		reviews.POST("/:id/respond", s.handleRespondToReview())
	}

	// ── Notification routes ─────────────────────────────────────
	notifications := protected.Group("/notifications")
	{
		notifications.GET("", s.handleListNotifications())
		notifications.PUT("/:id/read", s.handleMarkNotificationRead())
		notifications.PUT("/preferences", s.handleUpdateNotifPreferences())
	}

	// ── Search routes ───────────────────────────────────────────
	search := protected.Group("/search")
	{
		search.GET("/teachers", s.handleSearchTeachers())
		search.GET("/courses", s.handleSearchCourses())
	}

	// ── Admin routes ────────────────────────────────────────────
	admin := protected.Group("/admin")
	admin.Use(middleware.RequireRole("admin"))
	{
		admin.GET("/users", s.handleAdminListUsers())
		admin.GET("/users/:id", s.handleAdminGetUser())
		admin.PUT("/users/:id/suspend", s.handleAdminSuspendUser())

		admin.GET("/verifications", s.handleAdminListVerifications())
		admin.PUT("/verifications/:id/approve", s.handleAdminApproveTeacher())
		admin.PUT("/verifications/:id/reject", s.handleAdminRejectTeacher())

		admin.GET("/transactions", s.handleAdminListTransactions())
		admin.GET("/disputes", s.handleAdminListDisputes())
		admin.PUT("/disputes/:id/resolve", s.handleAdminResolveDispute())

		admin.GET("/analytics/overview", s.handleAdminAnalyticsOverview())
		admin.GET("/analytics/revenue", s.handleAdminAnalyticsRevenue())

		admin.PUT("/config/subjects", s.handleAdminUpdateSubjects())
		admin.PUT("/config/levels", s.handleAdminUpdateLevels())
	}
}
