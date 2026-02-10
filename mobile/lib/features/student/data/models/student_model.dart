import 'package:educonnect/features/student/domain/entities/student.dart';

class StudentProfileModel extends StudentProfile {
  const StudentProfileModel({
    required super.id,
    required super.userId,
    required super.firstName,
    required super.lastName,
    required super.level,
    super.filiere,
    super.school,
    super.wilaya,
    super.bio,
    super.avatarUrl,
    required super.createdAt,
    required super.updatedAt,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      level: json['level'] as String? ?? '',
      filiere: json['filiere'] as String?,
      school: json['school'] as String?,
      wilaya: json['wilaya'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class StudentDashboardModel extends StudentDashboard {
  const StudentDashboardModel({
    super.firstName,
    super.lastName,
    super.email,
    super.levelName,
    super.levelCode,
    super.cycle,
    super.totalSessions,
    super.totalCourses,
  });

  factory StudentDashboardModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    return StudentDashboardModel(
      firstName: profile['first_name'] as String? ?? '',
      lastName: profile['last_name'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      levelName: profile['level_name'] as String? ?? '',
      levelCode: profile['level_code'] as String? ?? '',
      cycle: profile['cycle'] as String? ?? '',
      totalSessions: json['total_sessions'] as int? ?? 0,
      totalCourses: json['total_courses'] as int? ?? 0,
    );
  }
}

class StudentSessionBriefModel extends StudentSessionBrief {
  const StudentSessionBriefModel({
    required super.id,
    required super.title,
    required super.teacherName,
    required super.startTime,
    required super.status,
    required super.type,
  });

  factory StudentSessionBriefModel.fromJson(Map<String, dynamic> json) {
    return StudentSessionBriefModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}

class StudentEnrollmentModel extends StudentEnrollment {
  const StudentEnrollmentModel({
    required super.id,
    required super.courseId,
    required super.courseName,
    super.progress,
    required super.enrolledAt,
    required super.status,
  });

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return StudentEnrollmentModel(
      id: json['id'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      enrolledAt: DateTime.tryParse(json['enrolled_at'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? '',
    );
  }
}
