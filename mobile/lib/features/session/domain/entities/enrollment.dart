import 'package:equatable/equatable.dart';

/// Represents an enrollment/invitation to a session series
class Enrollment extends Equatable {
  final String id;
  final String seriesId;
  final String seriesTitle;
  final String? teacherName;
  final String studentId;
  final String studentName;
  final String initiatedBy; // 'teacher' or 'student'
  final String status; // invited, requested, accepted, declined, removed
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? removedAt;
  final String? declineReason;
  final String? removeReason;

  const Enrollment({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    this.teacherName,
    required this.studentId,
    required this.studentName,
    required this.initiatedBy,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.declinedAt,
    this.removedAt,
    this.declineReason,
    this.removeReason,
  });

  bool get isPending => status == 'invited' || status == 'requested';
  bool get isInvitation => status == 'invited';
  bool get isRequest => status == 'requested';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isRemoved => status == 'removed';
  bool get isTeacherInitiated => initiatedBy == 'teacher';
  bool get isStudentInitiated => initiatedBy == 'student';

  @override
  List<Object?> get props => [id];
}
