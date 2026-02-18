import '../../domain/entities/booking_message.dart';

class BookingMessageModel extends BookingMessage {
  const BookingMessageModel({
    required super.id,
    required super.bookingId,
    required super.senderId,
    required super.senderName,
    required super.senderRole,
    required super.content,
    required super.createdAt,
  });

  factory BookingMessageModel.fromJson(Map<String, dynamic> json) {
    return BookingMessageModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? '',
      senderRole: json['sender_role'] as String? ?? 'student',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
