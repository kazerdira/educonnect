import '../../domain/entities/enrollment.dart';

class EnrollmentModel extends Enrollment {
  const EnrollmentModel({
    required super.id,
    required super.seriesId,
    required super.seriesTitle,
    super.teacherName,
    required super.studentId,
    required super.studentName,
    required super.initiatedBy,
    required super.status,
    required super.createdAt,
    super.acceptedAt,
    super.declinedAt,
    super.removedAt,
    super.declineReason,
    super.removeReason,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      id: json['id'] as String,
      seriesId: json['series_id'] as String,
      seriesTitle: json['series_title'] as String? ?? '',
      teacherName: json['teacher_name'] as String?,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String? ?? '',
      initiatedBy: json['initiated_by'] as String? ?? 'teacher',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      declinedAt: json['declined_at'] != null
          ? DateTime.parse(json['declined_at'] as String)
          : null,
      removedAt: json['removed_at'] != null
          ? DateTime.parse(json['removed_at'] as String)
          : null,
      declineReason: json['decline_reason'] as String?,
      removeReason: json['remove_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'series_id': seriesId,
      'series_title': seriesTitle,
      'teacher_name': teacherName,
      'student_id': studentId,
      'student_name': studentName,
      'initiated_by': initiatedBy,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'declined_at': declinedAt?.toIso8601String(),
      'removed_at': removedAt?.toIso8601String(),
      'decline_reason': declineReason,
      'remove_reason': removeReason,
    };
  }
}

/// Request model for requesting to join a series
class RequestToJoinRequest {
  final String? message;

  const RequestToJoinRequest({this.message});

  Map<String, dynamic> toJson() {
    return {
      if (message != null) 'message': message,
    };
  }
}

/// Request model for accepting/declining enrollment
class EnrollmentActionRequest {
  final String? reason;

  const EnrollmentActionRequest({this.reason});

  Map<String, dynamic> toJson() {
    return {
      if (reason != null) 'reason': reason,
    };
  }
}
