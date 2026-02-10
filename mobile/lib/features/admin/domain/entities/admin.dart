import 'package:equatable/equatable.dart';

class AdminUser extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final bool isActive;
  final bool isSuspended;
  final bool isVerified;
  final String createdAt;
  final String updatedAt;
  final String? lastLogin;

  const AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.isSuspended,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id];
}

class Verification extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String documentType;
  final String documentUrl;
  final String status;
  final String? reviewedBy;
  final String? reviewNote;
  final String createdAt;

  const Verification({
    required this.id,
    required this.userId,
    required this.userName,
    required this.documentType,
    required this.documentUrl,
    required this.status,
    this.reviewedBy,
    this.reviewNote,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}

class Dispute extends Equatable {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final String type;
  final String description;
  final String status;
  final String? resolution;
  final String? resolvedBy;
  final String? evidence;
  final String createdAt;
  final String updatedAt;

  const Dispute({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    required this.type,
    required this.description,
    required this.status,
    this.resolution,
    this.resolvedBy,
    this.evidence,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class AnalyticsOverview extends Equatable {
  final int totalUsers;
  final int totalTeachers;
  final int totalStudents;
  final int totalParents;
  final int totalSessions;
  final int totalCourses;
  final double totalRevenue;
  final int activeSessions;
  final int pendingVerifications;
  final int openDisputes;

  const AnalyticsOverview({
    required this.totalUsers,
    required this.totalTeachers,
    required this.totalStudents,
    required this.totalParents,
    required this.totalSessions,
    required this.totalCourses,
    required this.totalRevenue,
    required this.activeSessions,
    required this.pendingVerifications,
    required this.openDisputes,
  });

  @override
  List<Object?> get props => [
        totalUsers,
        totalTeachers,
        totalStudents,
        totalParents,
        totalSessions,
        totalCourses,
        totalRevenue,
        activeSessions,
        pendingVerifications,
        openDisputes,
      ];
}

class RevenueAnalytics extends Equatable {
  final double totalRevenue;
  final double monthlyRevenue;
  final double commission;
  final String period;
  final String currency;

  const RevenueAnalytics({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.commission,
    required this.period,
    required this.currency,
  });

  @override
  List<Object?> get props => [totalRevenue, monthlyRevenue, period];
}

class Subject extends Equatable {
  final String? id;
  final String nameAr;
  final String nameFr;
  final String code;

  const Subject({
    this.id,
    required this.nameAr,
    required this.nameFr,
    required this.code,
  });

  @override
  List<Object?> get props => [id, code];
}

class Level extends Equatable {
  final String? id;
  final String nameAr;
  final String nameFr;
  final String code;
  final String cycle;

  const Level({
    this.id,
    required this.nameAr,
    required this.nameFr,
    required this.code,
    required this.cycle,
  });

  @override
  List<Object?> get props => [id, code];
}
