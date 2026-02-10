import 'package:educonnect/features/student/domain/entities/student.dart';

abstract class StudentRepository {
  Future<StudentDashboard> getDashboard();
  Future<List<StudentSessionBrief>> getProgress();
  Future<List<StudentEnrollment>> getEnrollments();
}
