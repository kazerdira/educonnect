import 'package:equatable/equatable.dart';
import '../../domain/entities/booking_message.dart';
import '../../domain/entities/booking_request.dart';

abstract class BookingState extends Equatable {
  const BookingState();
  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

class BookingCreateSuccess extends BookingState {
  final BookingRequest booking;
  const BookingCreateSuccess(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingListLoaded extends BookingState {
  final List<BookingRequest> bookings;
  final int page;
  final bool hasMore;

  const BookingListLoaded({
    required this.bookings,
    required this.page,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [bookings, page, hasMore];
}

class BookingAccepted extends BookingState {
  final BookingRequest booking;
  const BookingAccepted(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingDeclined extends BookingState {
  final BookingRequest booking;
  const BookingDeclined(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingCancelled extends BookingState {}

class MessagesLoaded extends BookingState {
  final List<BookingMessage> messages;
  final String bookingId;

  const MessagesLoaded({required this.messages, required this.bookingId});

  @override
  List<Object?> get props => [messages, bookingId];
}

class MessageSent extends BookingState {
  final BookingMessage message;

  const MessageSent(this.message);

  @override
  List<Object?> get props => [message];
}

class BookingError extends BookingState {
  final String message;
  const BookingError(this.message);
  @override
  List<Object?> get props => [message];
}
