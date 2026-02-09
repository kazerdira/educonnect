class ApiConstants {
  ApiConstants._();

  // Change to your machine's IP for physical device testing
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Auth
  static const String registerTeacher = '/auth/register/teacher';
  static const String registerParent = '/auth/register/parent';
  static const String registerStudent = '/auth/register/student';
  static const String login = '/auth/login';
  static const String phoneLogin = '/auth/login/phone';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Users
  static const String profile = '/users/me';
  static const String avatar = '/users/me/avatar';
  static const String changePassword = '/users/me/password';

  // Teachers
  static const String teachers = '/teachers';
  static const String offerings = '/teachers/offerings';
  static const String availability = '/teachers/availability';
  static const String earnings = '/teachers/earnings';

  // Sessions
  static const String sessions = '/sessions';

  // Courses
  static const String courses = '/courses';

  // Search
  static const String searchTeachers = '/search/teachers';
  static const String searchCourses = '/search/courses';

  // Payments
  static const String payments = '/payments';

  // Notifications
  static const String notifications = '/notifications';
}
