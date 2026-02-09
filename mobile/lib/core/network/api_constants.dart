class ApiConstants {
  ApiConstants._();

  // Change to your machine's IP for physical device testing
  static const String baseUrl = 'http://192.168.1.15:8080/api/v1';

  // ── Auth (9 routes) ─────────────────────────────────────────
  static const String registerTeacher = '/auth/register/teacher';
  static const String registerParent = '/auth/register/parent';
  static const String registerStudent = '/auth/register/student';
  static const String login = '/auth/login';
  static const String phoneLogin = '/auth/login/phone';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ── Users (5 routes) ────────────────────────────────────────
  static const String profile = '/users/me'; // GET & PUT
  static const String avatar = '/users/me/avatar'; // PUT
  static const String changePassword = '/users/me/password'; // PUT
  static const String deactivateAccount = '/users/me'; // DELETE

  // ── Teachers (12 routes) ────────────────────────────────────
  static const String teachers = '/teachers'; // GET list
  static String teacherDetail(String id) => '/teachers/$id'; // GET one
  static const String teacherProfile = '/teachers/profile'; // PUT
  static const String teacherDashboard = '/teachers/dashboard'; // GET
  static const String offerings = '/teachers/offerings'; // POST & GET list
  static String offeringDetail(String id) =>
      '/teachers/offerings/$id'; // PUT & DELETE
  static const String availability = '/teachers/availability'; // PUT & GET
  static const String earnings = '/teachers/earnings'; // GET
  static const String payouts = '/teachers/payouts'; // POST

  // ── Students (3 routes) ─────────────────────────────────────
  static const String studentDashboard = '/students/dashboard'; // GET
  static const String studentProgress = '/students/progress'; // GET
  static const String studentEnrollments = '/students/enrollments'; // GET

  // ── Parents (6 routes) ──────────────────────────────────────
  static const String children = '/parents/children'; // POST & GET list
  static String childDetail(String id) =>
      '/parents/children/$id'; // PUT & DELETE
  static String childProgress(String id) =>
      '/parents/children/$id/progress'; // GET
  static const String parentDashboard = '/parents/dashboard'; // GET

  // ── Sessions (8 routes) ─────────────────────────────────────
  static const String sessions = '/sessions'; // POST & GET list
  static String sessionDetail(String id) => '/sessions/$id'; // GET
  static String joinSession(String id) => '/sessions/$id/join'; // POST
  static String cancelSession(String id) => '/sessions/$id/cancel'; // POST
  static String rescheduleSession(String id) =>
      '/sessions/$id/reschedule'; // PUT
  static String endSession(String id) => '/sessions/$id/end'; // POST
  static String sessionRecording(String id) => '/sessions/$id/recording'; // GET

  // ── Courses (9 routes) ──────────────────────────────────────
  static const String courses = '/courses'; // POST & GET list
  static String courseDetail(String id) => '/courses/$id'; // GET, PUT & DELETE
  static String courseChapters(String id) => '/courses/$id/chapters'; // POST
  static String courseLessons(String id) => '/courses/$id/lessons'; // POST
  static String courseVideo(String id) => '/courses/$id/video'; // POST
  static String enrollCourse(String id) => '/courses/$id/enroll'; // POST

  // ── Homework (5 routes) ─────────────────────────────────────
  static const String homework = '/homework'; // POST & GET list
  static String homeworkDetail(String id) => '/homework/$id'; // GET
  static String submitHomework(String id) => '/homework/$id/submit'; // POST
  static String gradeHomework(String id) => '/homework/$id/grade'; // PUT

  // ── Quizzes (5 routes) ──────────────────────────────────────
  static const String quizzes = '/quizzes'; // POST & GET list
  static String quizDetail(String id) => '/quizzes/$id'; // GET
  static String attemptQuiz(String id) => '/quizzes/$id/attempt'; // POST
  static String quizResults(String id) => '/quizzes/$id/results'; // GET

  // ── Payments (4 routes) ─────────────────────────────────────
  static const String payments = '/payments'; // base
  static const String initiatePayment = '/payments/initiate'; // POST
  static const String confirmPayment = '/payments/confirm'; // POST
  static const String paymentHistory = '/payments/history'; // GET
  static const String refundPayment = '/payments/refund'; // POST

  // ── Subscriptions (3 routes) ────────────────────────────────
  static const String subscriptions = '/subscriptions'; // POST & GET list
  static String cancelSubscription(String id) => '/subscriptions/$id'; // DELETE

  // ── Reviews (3 routes) ──────────────────────────────────────
  static const String reviews = '/reviews'; // POST
  static String teacherReviews(String teacherId) =>
      '/reviews/teacher/$teacherId'; // GET
  static String respondToReview(String id) => '/reviews/$id/respond'; // POST

  // ── Notifications (3 routes) ────────────────────────────────
  static const String notifications = '/notifications'; // GET list
  static String markNotificationRead(String id) =>
      '/notifications/$id/read'; // PUT
  static const String notificationPreferences =
      '/notifications/preferences'; // PUT

  // ── Search (2 routes) ───────────────────────────────────────
  static const String searchTeachers = '/search/teachers'; // GET
  static const String searchCourses = '/search/courses'; // GET

  // ── Admin (13 routes) ───────────────────────────────────────
  static const String adminUsers = '/admin/users'; // GET list
  static String adminUserDetail(String id) => '/admin/users/$id'; // GET
  static String adminSuspendUser(String id) =>
      '/admin/users/$id/suspend'; // PUT
  static const String adminVerifications = '/admin/verifications'; // GET list
  static String adminApproveTeacher(String id) =>
      '/admin/verifications/$id/approve'; // PUT
  static String adminRejectTeacher(String id) =>
      '/admin/verifications/$id/reject'; // PUT
  static const String adminTransactions = '/admin/transactions'; // GET list
  static const String adminDisputes = '/admin/disputes'; // GET list
  static String adminResolveDispute(String id) =>
      '/admin/disputes/$id/resolve'; // PUT
  static const String adminAnalyticsOverview =
      '/admin/analytics/overview'; // GET
  static const String adminAnalyticsRevenue = '/admin/analytics/revenue'; // GET
  static const String adminUpdateSubjects = '/admin/subjects'; // PUT
  static const String adminUpdateLevels = '/admin/levels'; // PUT
}
