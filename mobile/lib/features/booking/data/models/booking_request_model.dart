import '../../domain/entities/booking_request.dart';

class BookingRequestModel extends BookingRequest {
  const BookingRequestModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    required super.teacherId,
    required super.teacherName,
    super.offeringId,
    required super.subjectName,
    required super.levelName,
    required super.sessionType,
    required super.requestedDate,
    required super.startTime,
    required super.endTime,
    required super.message,
    required super.purpose,
    required super.status,
    super.declineReason,
    super.sessionId,
    super.seriesId,
    super.bookedByParentId,
    super.bookedByParentName,
    required super.createdAt,
    required super.updatedAt,
  });

  factory BookingRequestModel.fromJson(Map<String, dynamic> json) {
    return BookingRequestModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String? ?? '',
      teacherId: json['teacher_id'] as String,
      teacherName: json['teacher_name'] as String? ?? '',
      offeringId: json['offering_id'] as String?,
      subjectName: json['subject_name'] as String? ?? '',
      levelName: json['level_name'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? 'individual',
      requestedDate: DateTime.parse(json['requested_date'] as String),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      message: json['message'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      declineReason: json['decline_reason'] as String?,
      sessionId: json['session_id'] as String?,
      seriesId: json['series_id'] as String?,
      bookedByParentId: json['booked_by_parent_id'] as String?,
      bookedByParentName: json['booked_by_parent_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static BookingStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return BookingStatus.pending;
      case 'accepted':
        return BookingStatus.accepted;
      case 'declined':
        return BookingStatus.declined;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'offering_id': offeringId,
      'subject_name': subjectName,
      'level_name': levelName,
      'session_type': sessionType,
      'requested_date': requestedDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'message': message,
      'purpose': purpose,
      'status': status.name,
      'decline_reason': declineReason,
      'session_id': sessionId,
      'series_id': seriesId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
