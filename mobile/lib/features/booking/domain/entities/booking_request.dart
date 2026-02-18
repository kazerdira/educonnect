import 'package:equatable/equatable.dart';

enum BookingStatus { pending, accepted, declined, cancelled }

class BookingRequest extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final String? offeringId;
  final String subjectName;
  final String levelName;
  final String sessionType;
  final DateTime requestedDate;
  final String startTime;
  final String endTime;
  final String message;
  final String purpose;
  final BookingStatus status;
  final String? declineReason;
  final String? sessionId;
  final String? seriesId;
  // Parent booking fields
  final String? bookedByParentId;
  final String? bookedByParentName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    this.offeringId,
    required this.subjectName,
    required this.levelName,
    required this.sessionType,
    required this.requestedDate,
    required this.startTime,
    required this.endTime,
    required this.message,
    required this.purpose,
    required this.status,
    this.declineReason,
    this.sessionId,
    this.seriesId,
    this.bookedByParentId,
    this.bookedByParentName,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this booking was made by a parent for their child
  bool get isParentBooking => bookedByParentId != null;

  String get formattedDate {
    final months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${requestedDate.day} ${months[requestedDate.month - 1]} ${requestedDate.year}';
  }

  String get formattedTime => '$startTime - $endTime';

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'En attente';
      case BookingStatus.accepted:
        return 'Acceptée';
      case BookingStatus.declined:
        return 'Refusée';
      case BookingStatus.cancelled:
        return 'Annulée';
    }
  }

  @override
  List<Object?> get props => [id];
}
