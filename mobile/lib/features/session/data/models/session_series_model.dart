import '../../domain/entities/session_series.dart';

class SessionSeriesModel extends SessionSeries {
  const SessionSeriesModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    super.offeringId,
    super.subjectName,
    super.levelName,
    required super.title,
    super.description,
    required super.sessionType,
    required super.durationHours,
    required super.minStudents,
    required super.maxStudents,
    required super.pricePerHour,
    required super.totalSessions,
    required super.status,
    required super.isFinalized,
    super.finalizedAt,
    super.sessions = const [],
    super.enrollments = const [],
    required super.enrolledCount,
    required super.pendingCount,
    required super.starCost,
    required super.createdAt,
    required super.updatedAt,
    super.currentUserStatus,
  });

  factory SessionSeriesModel.fromJson(Map<String, dynamic> json) {
    return SessionSeriesModel(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String,
      teacherName: json['teacher_name'] as String? ?? '',
      offeringId: json['offering_id'] as String?,
      subjectName: json['subject_name'] as String?,
      levelName: json['level_name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      sessionType: json['session_type'] as String,
      durationHours: (json['duration_hours'] as num).toDouble(),
      minStudents: json['min_students'] as int? ?? 1,
      maxStudents: json['max_students'] as int? ?? 1,
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      status: json['status'] as String,
      isFinalized: json['is_finalized'] as bool? ?? false,
      finalizedAt: json['finalized_at'] != null
          ? DateTime.parse(json['finalized_at'] as String)
          : null,
      sessions: (json['sessions'] as List<dynamic>?)
              ?.map(
                  (e) => SessionBriefModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      enrollments: (json['enrollments'] as List<dynamic>?)
              ?.map((e) =>
                  EnrollmentBriefModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      starCost: (json['star_cost'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      currentUserStatus: json['current_user_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'offering_id': offeringId,
      'subject_name': subjectName,
      'level_name': levelName,
      'title': title,
      'description': description,
      'session_type': sessionType,
      'duration_hours': durationHours,
      'min_students': minStudents,
      'max_students': maxStudents,
      'price_per_hour': pricePerHour,
      'total_sessions': totalSessions,
      'status': status,
      'is_finalized': isFinalized,
      'finalized_at': finalizedAt?.toIso8601String(),
      'enrolled_count': enrolledCount,
      'pending_count': pendingCount,
      'star_cost': starCost,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class SessionBriefModel extends SessionBrief {
  const SessionBriefModel({
    required super.id,
    required super.sessionNumber,
    required super.title,
    required super.startTime,
    required super.endTime,
    required super.status,
  });

  factory SessionBriefModel.fromJson(Map<String, dynamic> json) {
    return SessionBriefModel(
      id: json['id'] as String,
      sessionNumber: json['session_number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_number': sessionNumber,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status,
    };
  }
}

class EnrollmentBriefModel extends EnrollmentBrief {
  const EnrollmentBriefModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    required super.initiatedBy,
    required super.status,
    required super.createdAt,
    super.acceptedAt,
  });

  factory EnrollmentBriefModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentBriefModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String? ?? '',
      initiatedBy: json['initiated_by'] as String? ?? 'teacher',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'initiated_by': initiatedBy,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }
}

/// Request model for creating a new series
class CreateSeriesRequest {
  final String? offeringId;
  final String? levelId;
  final String? subjectId;
  final String title;
  final String? description;
  final String sessionType;
  final double durationHours;
  final int minStudents;
  final int maxStudents;
  final double pricePerHour;

  const CreateSeriesRequest({
    this.offeringId,
    this.levelId,
    this.subjectId,
    required this.title,
    this.description,
    required this.sessionType,
    required this.durationHours,
    this.minStudents = 1,
    this.maxStudents = 1,
    this.pricePerHour = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      if (offeringId != null) 'offering_id': offeringId,
      if (levelId != null) 'level_id': levelId,
      if (subjectId != null) 'subject_id': subjectId,
      'title': title,
      if (description != null) 'description': description,
      'session_type': sessionType,
      'duration_hours': durationHours,
      'min_students': minStudents,
      'max_students': maxStudents,
      'price_per_hour': pricePerHour,
    };
  }
}

/// Request model for adding sessions to a series
class AddSessionsRequest {
  final List<SessionInput> sessions;

  const AddSessionsRequest({required this.sessions});

  Map<String, dynamic> toJson() {
    return {
      'sessions': sessions.map((s) => s.toJson()).toList(),
    };
  }
}

class SessionInput {
  final DateTime startTime;
  final String? title;

  const SessionInput({
    required this.startTime,
    this.title,
  });

  Map<String, dynamic> toJson() {
    // Format as RFC3339 with timezone (required by backend)
    final utc = startTime.toUtc();
    return {
      'start_time': '${utc.toIso8601String().split('.').first}Z',
      if (title != null) 'title': title,
    };
  }
}

/// Request model for inviting students
class InviteStudentsRequest {
  final List<String> studentIds;
  final String? message;

  const InviteStudentsRequest({
    required this.studentIds,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_ids': studentIds,
      if (message != null) 'message': message,
    };
  }
}
