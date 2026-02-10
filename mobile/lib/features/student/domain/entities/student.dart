import 'package:equatable/equatable.dart';

class StudentProfile extends Equatable {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String level;
  final String? filiere;
  final String? school;
  final String? wilaya;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.level,
    this.filiere,
    this.school,
    this.wilaya,
    this.bio,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, userId, firstName, lastName];
}

class StudentDashboard extends Equatable {
  final String firstName;
  final String lastName;
  final String email;
  final String levelName;
  final String levelCode;
  final String cycle;
  final int totalSessions;
  final int totalCourses;

  const StudentDashboard({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.levelName = '',
    this.levelCode = '',
    this.cycle = '',
    this.totalSessions = 0,
    this.totalCourses = 0,
  });

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        email,
        totalSessions,
        totalCourses,
      ];
}

class StudentSessionBrief extends Equatable {
  final String id;
  final String title;
  final String teacherName;
  final DateTime startTime;
  final String status;
  final String type;

  const StudentSessionBrief({
    required this.id,
    required this.title,
    required this.teacherName,
    required this.startTime,
    required this.status,
    required this.type,
  });

  @override
  List<Object?> get props => [id, title, startTime, status];
}

class StudentEnrollment extends Equatable {
  final String id;
  final String courseId;
  final String courseName;
  final double progress;
  final DateTime enrolledAt;
  final String status;

  const StudentEnrollment({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.progress = 0.0,
    required this.enrolledAt,
    required this.status,
  });

  @override
  List<Object?> get props => [id, courseId, status];
}
