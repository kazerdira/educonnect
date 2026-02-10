import 'package:educonnect/features/teacher/domain/entities/teacher_profile.dart';

class TeacherProfileModel extends TeacherProfile {
  const TeacherProfileModel({
    required super.userId,
    required super.firstName,
    required super.lastName,
    super.avatarUrl,
    required super.email,
    super.phone,
    super.wilaya,
    super.bio,
    super.experienceYears,
    super.specializations,
    super.verificationStatus,
    super.ratingAvg,
    super.ratingCount,
    super.totalSessions,
    super.totalStudents,
    super.completionRate,
  });

  factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
    return TeacherProfileModel(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      wilaya: json['wilaya'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      totalStudents: json['total_students'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'email': email,
      'phone': phone,
      'wilaya': wilaya,
      'bio': bio,
      'experience_years': experienceYears,
      'specializations': specializations,
      'verification_status': verificationStatus,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'total_sessions': totalSessions,
      'total_students': totalStudents,
      'completion_rate': completionRate,
    };
  }
}
