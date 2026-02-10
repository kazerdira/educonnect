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

  /// GET /students/progress  (recent sessions)
  /// NOTE: Backend returns a Map {profile, total_courses, total_sessions, ...}
  /// not a List. We extract progress items from inside if present.
  Future<List<StudentSessionBriefModel>> getProgress() async {
    final response = await apiClient.dio.get(ApiConstants.studentProgress);
    final raw = response.data['data'];
    if (raw == null) return [];
    // Backend actually returns a Map, not a List
    if (raw is Map<String, dynamic>) {
      final sessions = raw['recent_sessions'] as List<dynamic>? ?? [];
      return sessions
          .map((e) =>
              StudentSessionBriefModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (raw is List<dynamic>) {
      return raw
          .map((e) =>
              StudentSessionBriefModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
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
