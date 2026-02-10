import 'package:educonnect/features/student/data/datasources/student_remote_datasource.dart';
import 'package:educonnect/features/student/domain/entities/student.dart';
import 'package:educonnect/features/student/domain/repositories/student_repository.dart';

class StudentRepositoryImpl implements StudentRepository {
  final StudentRemoteDataSource remoteDataSource;

  StudentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<StudentDashboard> getDashboard() {
    return remoteDataSource.getDashboard();
  }

  @override
  Future<List<StudentSessionBrief>> getProgress() {
    return remoteDataSource.getProgress();
  }

  @override
  Future<List<StudentEnrollment>> getEnrollments() {
    return remoteDataSource.getEnrollments();
  }
}
