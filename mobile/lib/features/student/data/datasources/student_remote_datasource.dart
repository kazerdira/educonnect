import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/student/data/models/student_model.dart';

class StudentRemoteDataSource {
  final ApiClient apiClient;

  StudentRemoteDataSource({required this.apiClient});

  /// GET /students/dashboard
  Future<StudentDashboardModel> getDashboard() async {
    final response = await apiClient.dio.get(ApiConstants.studentDashboard);
    final data = response.data['data'];
    if (data == null) {
      return const StudentDashboardModel();
    }
    return StudentDashboardModel.fromJson(data as Map<String, dynamic>);
  }

  /// GET /students/progress
  /// Backend returns {total_sessions, total_courses, profile} — no sessions list.
  /// Upcoming sessions come from the dashboard endpoint instead.
  /// This method is kept for the progress stats; sessions are parsed in dashboard.
  Future<List<StudentSessionBriefModel>> getProgress() async {
    // The progress endpoint does not return a sessions list,
    // so we return an empty list. Upcoming sessions are already
    // parsed from the dashboard response.
    return [];
  }

  /// GET /students/enrollments
  Future<List<StudentEnrollmentModel>> getEnrollments() async {
    final response = await apiClient.dio.get(ApiConstants.studentEnrollments);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => StudentEnrollmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
