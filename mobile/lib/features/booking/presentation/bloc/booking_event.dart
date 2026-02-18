import 'package:equatable/equatable.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class CreateBookingRequested extends BookingEvent {
  final String teacherId;
  final String? offeringId;
  final String sessionType;
  final DateTime requestedDate;
  final String startTime;
  final String endTime;
  final String? message;
  final String? purpose;
  final String? forChildId;

  const CreateBookingRequested({
    required this.teacherId,
    this.offeringId,
    required this.sessionType,
    required this.requestedDate,
    required this.startTime,
    required this.endTime,
    this.message,
    this.purpose,
    this.forChildId,
  });

  @override
  List<Object?> get props => [
        teacherId,
        offeringId,
        sessionType,
        requestedDate,
        startTime,
        endTime,
        message,
        purpose,
        forChildId,
      ];
}

class LoadBookingsRequested extends BookingEvent {
  final String role; // 'as_student' or 'as_teacher'
  final String? status;
  final int page;

  const LoadBookingsRequested({
    required this.role,
    this.status,
    this.page = 1,
  });

  @override
  List<Object?> get props => [role, status, page];
}

class AcceptBookingRequested extends BookingEvent {
  final String bookingId;
  final String? title;
  final String? description;
  final double price;
  final String? existingSeriesId;

  const AcceptBookingRequested({
    required this.bookingId,
    this.title,
    this.description,
    required this.price,
    this.existingSeriesId,
  });

  @override
  List<Object?> get props =>
      [bookingId, title, description, price, existingSeriesId];
}

class DeclineBookingRequested extends BookingEvent {
  final String bookingId;
  final String reason;

  const DeclineBookingRequested({
    required this.bookingId,
    required this.reason,
  });

  @override
  List<Object?> get props => [bookingId, reason];
}

class CancelBookingRequested extends BookingEvent {
  final String bookingId;

  const CancelBookingRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

// ── Booking conversation messages ──────────────────────────────

class LoadMessagesRequested extends BookingEvent {
  final String bookingId;
  final String? before;

  const LoadMessagesRequested({required this.bookingId, this.before});

  @override
  List<Object?> get props => [bookingId, before];
}

class SendMessageRequested extends BookingEvent {
  final String bookingId;
  final String content;

  const SendMessageRequested({required this.bookingId, required this.content});

  @override
  List<Object?> get props => [bookingId, content];
}
