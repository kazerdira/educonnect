import 'package:educonnect/features/admin/domain/entities/admin.dart';

class AdminUserModel extends AdminUser {
  const AdminUserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.role,
    required super.isActive,
    required super.isSuspended,
    required super.isVerified,
    required super.createdAt,
    required super.updatedAt,
    super.lastLogin,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isSuspended: json['is_suspended'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      lastLogin: json['last_login'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'is_active': isActive,
        'is_suspended': isSuspended,
        'is_verified': isVerified,
        'created_at': createdAt,
        'updated_at': updatedAt,
        if (lastLogin != null) 'last_login': lastLogin,
      };
}

class VerificationModel extends Verification {
  const VerificationModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.documentType,
    required super.documentUrl,
    required super.status,
    super.reviewedBy,
    super.reviewNote,
    required super.createdAt,
  });

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    return VerificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      documentUrl: json['document_url'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reviewedBy: json['reviewed_by'] as String?,
      reviewNote: json['review_note'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'document_type': documentType,
        'document_url': documentUrl,
        'status': status,
        if (reviewedBy != null) 'reviewed_by': reviewedBy,
        if (reviewNote != null) 'review_note': reviewNote,
        'created_at': createdAt,
      };
}

class DisputeModel extends Dispute {
  const DisputeModel({
    required super.id,
    required super.reporterId,
    required super.reporterName,
    required super.reportedId,
    required super.reportedName,
    required super.type,
    required super.description,
    required super.status,
    super.resolution,
    super.resolvedBy,
    super.evidence,
    required super.createdAt,
    required super.updatedAt,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    return DisputeModel(
      id: json['id'] as String? ?? '',
      reporterId: json['reporter_id'] as String? ?? '',
      reporterName: json['reporter_name'] as String? ?? '',
      reportedId: json['reported_id'] as String? ?? '',
      reportedName: json['reported_name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      resolution: json['resolution'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      evidence: json['evidence'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporter_id': reporterId,
        'reporter_name': reporterName,
        'reported_id': reportedId,
        'reported_name': reportedName,
        'type': type,
        'description': description,
        'status': status,
        if (resolution != null) 'resolution': resolution,
        if (resolvedBy != null) 'resolved_by': resolvedBy,
        if (evidence != null) 'evidence': evidence,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class AnalyticsOverviewModel extends AnalyticsOverview {
  const AnalyticsOverviewModel({
    required super.totalUsers,
    required super.totalTeachers,
    required super.totalStudents,
    required super.totalParents,
    required super.totalSessions,
    required super.totalCourses,
    required super.totalRevenue,
    required super.activeSessions,
    required super.pendingVerifications,
    required super.openDisputes,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverviewModel(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      totalTeachers: (json['total_teachers'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalParents: (json['total_parents'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      totalCourses: (json['total_courses'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      activeSessions: (json['active_sessions'] as num?)?.toInt() ?? 0,
      pendingVerifications:
          (json['pending_verifications'] as num?)?.toInt() ?? 0,
      openDisputes: (json['open_disputes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_users': totalUsers,
        'total_teachers': totalTeachers,
        'total_students': totalStudents,
        'total_parents': totalParents,
        'total_sessions': totalSessions,
        'total_courses': totalCourses,
        'total_revenue': totalRevenue,
        'active_sessions': activeSessions,
        'pending_verifications': pendingVerifications,
        'open_disputes': openDisputes,
      };
}

class RevenueAnalyticsModel extends RevenueAnalytics {
  const RevenueAnalyticsModel({
    required super.totalRevenue,
    required super.monthlyRevenue,
    required super.commission,
    required super.period,
    required super.currency,
  });

  factory RevenueAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return RevenueAnalyticsModel(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      monthlyRevenue: (json['monthly_revenue'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      period: json['period'] as String? ?? '',
      currency: json['currency'] as String? ?? 'DZD',
    );
  }

  Map<String, dynamic> toJson() => {
        'total_revenue': totalRevenue,
        'monthly_revenue': monthlyRevenue,
        'commission': commission,
        'period': period,
        'currency': currency,
      };
}

class SubjectModel extends Subject {
  const SubjectModel({
    super.id,
    required super.nameAr,
    required super.nameFr,
    required super.code,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String?,
      nameAr: json['name_ar'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name_ar': nameAr,
        'name_fr': nameFr,
        'code': code,
      };
}

class LevelModel extends Level {
  const LevelModel({
    super.id,
    required super.nameAr,
    required super.nameFr,
    required super.code,
    required super.cycle,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'] as String?,
      nameAr: json['name_ar'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      code: json['code'] as String? ?? '',
      cycle: json['cycle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name_ar': nameAr,
        'name_fr': nameFr,
        'code': code,
        'cycle': cycle,
      };
}
