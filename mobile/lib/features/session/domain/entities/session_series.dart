import 'package:equatable/equatable.dart';

/// Represents a series of sessions (or a single session)
class SessionSeries extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String? offeringId;
  final String? subjectName;
  final String? levelName;
  final String title;
  final String? description;
  final String sessionType; // 'one_on_one' or 'group'
  final double durationHours;
  final int minStudents;
  final int maxStudents;
  final double pricePerHour;
  final int totalSessions;
  final String status; // draft, active, finalized, completed, cancelled
  final bool isFinalized;
  final DateTime? finalizedAt;
  final List<SessionBrief> sessions;
  final List<EnrollmentBrief> enrollments;
  final int enrolledCount;
  final int pendingCount;
  final double starCost; // DZD per enrollment (50 group / 70 private)
  final DateTime createdAt;
  final DateTime updatedAt;
  // Current user's enrollment status when browsing (empty if not enrolled)
  final String?
      currentUserStatus; // 'invited', 'requested', 'enrolled', 'declined', ''

  const SessionSeries({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    this.offeringId,
    this.subjectName,
    this.levelName,
    required this.title,
    this.description,
    required this.sessionType,
    required this.durationHours,
    required this.minStudents,
    required this.maxStudents,
    required this.pricePerHour,
    required this.totalSessions,
    required this.status,
    required this.isFinalized,
    this.finalizedAt,
    this.sessions = const [],
    this.enrollments = const [],
    required this.enrolledCount,
    required this.pendingCount,
    required this.starCost,
    required this.createdAt,
    required this.updatedAt,
    this.currentUserStatus,
  });

  bool get isGroup => sessionType == 'group';
  bool get isIndividual => sessionType == 'one_on_one';
  bool get canFinalize =>
      !isFinalized && enrolledCount > 0 && totalSessions > 0;
  bool get canAddStudents => !isFinalized && enrolledCount < maxStudents;

  // Helpers for enrollment status
  bool get isEnrolled =>
      currentUserStatus ==
      'accepted'; // DB uses 'accepted' for enrolled students
  bool get hasPendingRequest => currentUserStatus == 'requested';
  bool get hasInvitation => currentUserStatus == 'invited';
  bool get isDeclined => currentUserStatus == 'declined';
  bool get canRequestToJoin =>
      currentUserStatus == null || currentUserStatus!.isEmpty;

  @override
  List<Object?> get props => [id];
}

/// Brief session info within a series
class SessionBrief extends Equatable {
  final String id;
  final int sessionNumber;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  const SessionBrief({
    required this.id,
    required this.sessionNumber,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  @override
  List<Object?> get props => [id];
}

/// Brief enrollment info within a series
class EnrollmentBrief extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String initiatedBy; // 'teacher' or 'student'
  final String status; // invited, requested, accepted, declined, removed
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const EnrollmentBrief({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.initiatedBy,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  bool get isPending => status == 'invited' || status == 'requested';
  bool get isAccepted => status == 'accepted';
  bool get isTeacherInitiated => initiatedBy == 'teacher';
  bool get isStudentInitiated => initiatedBy == 'student';

  @override
  List<Object?> get props => [id];
}
