import 'package:equatable/equatable.dart';

/// A single message in a booking conversation thread.
class BookingMessage extends Equatable {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'teacher' or 'student'
  final String content;
  final DateTime createdAt;

  const BookingMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  /// Whether the sender is the teacher
  bool get isTeacher => senderRole == 'teacher';

  @override
  List<Object?> get props => [id, bookingId, senderId, content, createdAt];
}
