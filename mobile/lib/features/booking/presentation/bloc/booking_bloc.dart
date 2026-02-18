import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/booking_repository.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository repository;

  BookingBloc({required this.repository}) : super(BookingInitial()) {
    on<CreateBookingRequested>(_onCreateBooking);
    on<LoadBookingsRequested>(_onLoadBookings);
    on<AcceptBookingRequested>(_onAcceptBooking);
    on<DeclineBookingRequested>(_onDeclineBooking);
    on<CancelBookingRequested>(_onCancelBooking);
    on<LoadMessagesRequested>(_onLoadMessages);
    on<SendMessageRequested>(_onSendMessage);
  }

  Future<void> _onCreateBooking(
    CreateBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final booking = await repository.createBookingRequest(
        teacherId: event.teacherId,
        offeringId: event.offeringId,
        sessionType: event.sessionType,
        requestedDate: event.requestedDate,
        startTime: event.startTime,
        endTime: event.endTime,
        message: event.message,
        purpose: event.purpose,
        forChildId: event.forChildId,
      );
      emit(BookingCreateSuccess(booking));
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  Future<void> _onLoadBookings(
    LoadBookingsRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final bookings = await repository.listBookingRequests(
        role: event.role,
        status: event.status,
        page: event.page,
      );
      emit(BookingListLoaded(
        bookings: bookings,
        page: event.page,
        hasMore: bookings.length == 20,
      ));
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  Future<void> _onAcceptBooking(
    AcceptBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final booking = await repository.acceptBookingRequest(
        bookingId: event.bookingId,
        title: event.title,
        description: event.description,
        price: event.price,
        existingSeriesId: event.existingSeriesId,
      );
      emit(BookingAccepted(booking));
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  Future<void> _onDeclineBooking(
    DeclineBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final booking = await repository.declineBookingRequest(
        bookingId: event.bookingId,
        reason: event.reason,
      );
      emit(BookingDeclined(booking));
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  Future<void> _onCancelBooking(
    CancelBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      await repository.cancelBookingRequest(event.bookingId);
      emit(BookingCancelled());
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  Future<void> _onLoadMessages(
    LoadMessagesRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final messages = await repository.listMessages(
        bookingId: event.bookingId,
        before: event.before,
      );
      emit(MessagesLoaded(messages: messages, bookingId: event.bookingId));
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  Future<void> _onSendMessage(
    SendMessageRequested event,
    Emitter<BookingState> emit,
  ) async {
    try {
      final message = await repository.sendMessage(
        bookingId: event.bookingId,
        content: event.content,
      );
      emit(MessageSent(message));
    } catch (e) {
      emit(BookingError(_extractError(e)));
    }
  }

  /// Extract a user-friendly error message from any exception.
  /// For Dio HTTP errors, reads the server's `error` field from the JSON body.
  String _extractError(Object e) {
    return extractApiError(e);
  }
}
