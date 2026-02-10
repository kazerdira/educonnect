import 'package:equatable/equatable.dart';

class TeacherProfile extends Equatable {
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String email;
  final String phone;
  final String wilaya;
  final String bio;
  final int experienceYears;
  final List<String> specializations;
  final String verificationStatus;
  final double ratingAvg;
  final int ratingCount;
  final int totalSessions;
  final int totalStudents;
  final double completionRate;

  const TeacherProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.email,
    this.phone = '',
    this.wilaya = '',
    this.bio = '',
    this.experienceYears = 0,
    this.specializations = const [],
    this.verificationStatus = 'pending',
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.totalSessions = 0,
    this.totalStudents = 0,
    this.completionRate = 0.0,
  });

  @override
  List<Object?> get props => [userId, email, firstName, lastName];
}
