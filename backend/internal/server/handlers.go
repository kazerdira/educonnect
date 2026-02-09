package server

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// ╔══════════════════════════════════════════════════════════════╗
// ║  Handler stubs — to be implemented per module               ║
// ║  Each returns a gin.HandlerFunc that will be wired up       ║
// ╚══════════════════════════════════════════════════════════════╝

func notImplemented() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"success": false,
			"error":   gin.H{"code": "NOT_IMPLEMENTED", "message": "This endpoint is not yet implemented"},
		})
	}
}

// ─── Auth ────────────────────────────────────────────────────
func (s *Server) handleRegisterTeacher() gin.HandlerFunc { return s.authHandler.RegisterTeacher }
func (s *Server) handleRegisterParent() gin.HandlerFunc  { return s.authHandler.RegisterParent }
func (s *Server) handleRegisterStudent() gin.HandlerFunc { return s.authHandler.RegisterStudent }
func (s *Server) handleLogin() gin.HandlerFunc           { return s.authHandler.Login }
func (s *Server) handlePhoneLogin() gin.HandlerFunc      { return s.authHandler.PhoneLogin }
func (s *Server) handleVerifyOTP() gin.HandlerFunc       { return s.authHandler.VerifyOTP }
func (s *Server) handleRefreshToken() gin.HandlerFunc    { return s.authHandler.RefreshToken }
func (s *Server) handleForgotPassword() gin.HandlerFunc  { return notImplemented() }
func (s *Server) handleResetPassword() gin.HandlerFunc   { return notImplemented() }

// ─── User ────────────────────────────────────────────────────
func (s *Server) handleGetProfile() gin.HandlerFunc        { return s.userHandler.GetProfile }
func (s *Server) handleUpdateProfile() gin.HandlerFunc     { return s.userHandler.UpdateProfile }
func (s *Server) handleUploadAvatar() gin.HandlerFunc      { return s.userHandler.UploadAvatar }
func (s *Server) handleChangePassword() gin.HandlerFunc    { return s.userHandler.ChangePassword }
func (s *Server) handleDeactivateAccount() gin.HandlerFunc { return s.userHandler.DeactivateAccount }

// ─── Teacher ─────────────────────────────────────────────────
func (s *Server) handleListTeachers() gin.HandlerFunc         { return s.teacherHandler.ListTeachers }
func (s *Server) handleGetTeacher() gin.HandlerFunc           { return s.teacherHandler.GetTeacher }
func (s *Server) handleUpdateTeacherProfile() gin.HandlerFunc { return s.teacherHandler.UpdateProfile }
func (s *Server) handleTeacherDashboard() gin.HandlerFunc     { return s.teacherHandler.Dashboard }
func (s *Server) handleCreateOffering() gin.HandlerFunc       { return s.teacherHandler.CreateOffering }
func (s *Server) handleListOfferings() gin.HandlerFunc        { return s.teacherHandler.ListOfferings }
func (s *Server) handleUpdateOffering() gin.HandlerFunc       { return s.teacherHandler.UpdateOffering }
func (s *Server) handleDeleteOffering() gin.HandlerFunc       { return s.teacherHandler.DeleteOffering }
func (s *Server) handleSetAvailability() gin.HandlerFunc      { return s.teacherHandler.SetAvailability }
func (s *Server) handleGetAvailability() gin.HandlerFunc      { return s.teacherHandler.GetAvailability }
func (s *Server) handleGetEarnings() gin.HandlerFunc          { return s.teacherHandler.GetEarnings }
func (s *Server) handleRequestPayout() gin.HandlerFunc        { return notImplemented() }

// ─── Student ─────────────────────────────────────────────────
func (s *Server) handleStudentDashboard() gin.HandlerFunc   { return s.studentHandler.Dashboard }
func (s *Server) handleStudentProgress() gin.HandlerFunc    { return s.studentHandler.Progress }
func (s *Server) handleStudentEnrollments() gin.HandlerFunc { return s.studentHandler.Enrollments }

// ─── Parent ──────────────────────────────────────────────────
func (s *Server) handleAddChild() gin.HandlerFunc        { return s.parentHandler.AddChild }
func (s *Server) handleListChildren() gin.HandlerFunc    { return s.parentHandler.ListChildren }
func (s *Server) handleUpdateChild() gin.HandlerFunc     { return s.parentHandler.UpdateChild }
func (s *Server) handleRemoveChild() gin.HandlerFunc     { return s.parentHandler.RemoveChild }
func (s *Server) handleChildProgress() gin.HandlerFunc   { return s.parentHandler.GetChildProgress }
func (s *Server) handleParentDashboard() gin.HandlerFunc { return s.parentHandler.Dashboard }

// ─── Session ─────────────────────────────────────────────────
func (s *Server) handleCreateSession() gin.HandlerFunc     { return s.sessionHandler.CreateSession }
func (s *Server) handleListSessions() gin.HandlerFunc      { return s.sessionHandler.ListSessions }
func (s *Server) handleGetSession() gin.HandlerFunc        { return s.sessionHandler.GetSession }
func (s *Server) handleJoinSession() gin.HandlerFunc       { return s.sessionHandler.JoinSession }
func (s *Server) handleCancelSession() gin.HandlerFunc     { return s.sessionHandler.CancelSession }
func (s *Server) handleRescheduleSession() gin.HandlerFunc { return s.sessionHandler.RescheduleSession }
func (s *Server) handleEndSession() gin.HandlerFunc        { return s.sessionHandler.EndSession }
func (s *Server) handleGetRecording() gin.HandlerFunc      { return notImplemented() }

// ─── Course ──────────────────────────────────────────────────
func (s *Server) handleCreateCourse() gin.HandlerFunc  { return s.courseHandler.CreateCourse }
func (s *Server) handleListCourses() gin.HandlerFunc   { return s.courseHandler.ListCourses }
func (s *Server) handleGetCourse() gin.HandlerFunc     { return s.courseHandler.GetCourse }
func (s *Server) handleUpdateCourse() gin.HandlerFunc  { return s.courseHandler.UpdateCourse }
func (s *Server) handleDeleteCourse() gin.HandlerFunc  { return s.courseHandler.DeleteCourse }
func (s *Server) handleCreateChapter() gin.HandlerFunc { return s.courseHandler.CreateChapter }
func (s *Server) handleCreateLesson() gin.HandlerFunc  { return s.courseHandler.CreateLesson }
func (s *Server) handleUploadVideo() gin.HandlerFunc   { return s.courseHandler.UploadVideo }
func (s *Server) handleEnrollCourse() gin.HandlerFunc  { return s.courseHandler.EnrollStudent }

// ─── Homework ────────────────────────────────────────────────
func (s *Server) handleCreateHomework() gin.HandlerFunc { return s.homeworkHandler.CreateHomework }
func (s *Server) handleListHomework() gin.HandlerFunc   { return s.homeworkHandler.ListHomework }
func (s *Server) handleGetHomework() gin.HandlerFunc    { return s.homeworkHandler.GetHomework }
func (s *Server) handleSubmitHomework() gin.HandlerFunc { return s.homeworkHandler.SubmitHomework }
func (s *Server) handleGradeHomework() gin.HandlerFunc  { return s.homeworkHandler.GradeHomework }

// ─── Quiz ────────────────────────────────────────────────────
func (s *Server) handleCreateQuiz() gin.HandlerFunc  { return s.quizHandler.CreateQuiz }
func (s *Server) handleListQuizzes() gin.HandlerFunc { return s.quizHandler.ListQuizzes }
func (s *Server) handleGetQuiz() gin.HandlerFunc     { return s.quizHandler.GetQuiz }
func (s *Server) handleAttemptQuiz() gin.HandlerFunc { return s.quizHandler.AttemptQuiz }
func (s *Server) handleQuizResults() gin.HandlerFunc { return s.quizHandler.QuizResults }

// ─── Payment ─────────────────────────────────────────────────
func (s *Server) handleInitiatePayment() gin.HandlerFunc { return s.paymentHandler.InitiatePayment }
func (s *Server) handleConfirmPayment() gin.HandlerFunc  { return s.paymentHandler.ConfirmPayment }
func (s *Server) handlePaymentHistory() gin.HandlerFunc  { return s.paymentHandler.PaymentHistory }
func (s *Server) handleRefundPayment() gin.HandlerFunc   { return s.paymentHandler.RefundPayment }

// ─── Subscription ────────────────────────────────────────────
func (s *Server) handleCreateSubscription() gin.HandlerFunc {
	return s.paymentHandler.CreateSubscription
}
func (s *Server) handleListSubscriptions() gin.HandlerFunc { return s.paymentHandler.ListSubscriptions }
func (s *Server) handleCancelSubscription() gin.HandlerFunc {
	return s.paymentHandler.CancelSubscription
}

// ─── Review ──────────────────────────────────────────────────
func (s *Server) handleCreateReview() gin.HandlerFunc      { return s.reviewHandler.CreateReview }
func (s *Server) handleGetTeacherReviews() gin.HandlerFunc { return s.reviewHandler.GetTeacherReviews }
func (s *Server) handleRespondToReview() gin.HandlerFunc   { return s.reviewHandler.RespondToReview }

// ─── Notification ────────────────────────────────────────────
func (s *Server) handleListNotifications() gin.HandlerFunc {
	return s.notificationHandler.ListNotifications
}
func (s *Server) handleMarkNotificationRead() gin.HandlerFunc {
	return s.notificationHandler.MarkNotificationRead
}
func (s *Server) handleUpdateNotifPreferences() gin.HandlerFunc {
	return s.notificationHandler.UpdateNotifPreferences
}

// ─── Search ──────────────────────────────────────────────────
func (s *Server) handleSearchTeachers() gin.HandlerFunc { return s.searchHandler.SearchTeachers }
func (s *Server) handleSearchCourses() gin.HandlerFunc  { return s.searchHandler.SearchCourses }

// ─── Admin ───────────────────────────────────────────────────
func (s *Server) handleAdminListUsers() gin.HandlerFunc   { return s.adminHandler.ListUsers }
func (s *Server) handleAdminGetUser() gin.HandlerFunc     { return s.adminHandler.GetUser }
func (s *Server) handleAdminSuspendUser() gin.HandlerFunc { return s.adminHandler.SuspendUser }
func (s *Server) handleAdminListVerifications() gin.HandlerFunc {
	return s.adminHandler.ListVerifications
}
func (s *Server) handleAdminApproveTeacher() gin.HandlerFunc { return s.adminHandler.ApproveTeacher }
func (s *Server) handleAdminRejectTeacher() gin.HandlerFunc  { return s.adminHandler.RejectTeacher }
func (s *Server) handleAdminListTransactions() gin.HandlerFunc {
	return s.adminHandler.ListTransactions
}
func (s *Server) handleAdminListDisputes() gin.HandlerFunc   { return s.adminHandler.ListDisputes }
func (s *Server) handleAdminResolveDispute() gin.HandlerFunc { return s.adminHandler.ResolveDispute }
func (s *Server) handleAdminAnalyticsOverview() gin.HandlerFunc {
	return s.adminHandler.AnalyticsOverview
}
func (s *Server) handleAdminAnalyticsRevenue() gin.HandlerFunc {
	return s.adminHandler.AnalyticsRevenue
}
func (s *Server) handleAdminUpdateSubjects() gin.HandlerFunc { return s.adminHandler.UpdateSubjects }
func (s *Server) handleAdminUpdateLevels() gin.HandlerFunc   { return s.adminHandler.UpdateLevels }
