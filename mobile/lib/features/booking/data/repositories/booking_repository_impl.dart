import '../../domain/entities/booking_message.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource remoteDataSource;

  BookingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<BookingRequest> createBookingRequest({
    required String teacherId,
    String? offeringId,
    required String sessionType,
    required DateTime requestedDate,
    required String startTime,
    required String endTime,
    String? message,
    String? purpose,
    String? forChildId,
  }) =>
      remoteDataSource.createBookingRequest(
        teacherId: teacherId,
        offeringId: offeringId,
        sessionType: sessionType,
        requestedDate: requestedDate.toIso8601String().split('T')[0],
        startTime: startTime,
        endTime: endTime,
        message: message,
        purpose: purpose,
        forChildId: forChildId,
      );

  @override
  Future<List<BookingRequest>> listBookingRequests({
    required String role,
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      remoteDataSource.listBookingRequests(
        role: role,
        status: status,
        page: page,
        limit: limit,
      );

  @override
  Future<BookingRequest> getBookingRequest(String id) =>
      remoteDataSource.getBookingRequest(id);

  @override
  Future<BookingRequest> acceptBookingRequest({
    required String bookingId,
    String? title,
    String? description,
    required double price,
    String? existingSeriesId,
  }) =>
      remoteDataSource.acceptBookingRequest(
        bookingId: bookingId,
        title: title,
        description: description,
        price: price,
        existingSeriesId: existingSeriesId,
      );

  @override
  Future<BookingRequest> declineBookingRequest({
    required String bookingId,
    required String reason,
  }) =>
      remoteDataSource.declineBookingRequest(
        bookingId: bookingId,
        reason: reason,
      );

  @override
  Future<void> cancelBookingRequest(String bookingId) =>
      remoteDataSource.cancelBookingRequest(bookingId);

  @override
  Future<BookingMessage> sendMessage({
    required String bookingId,
    required String content,
  }) =>
      remoteDataSource.sendMessage(
        bookingId: bookingId,
        content: content,
      );

  @override
  Future<List<BookingMessage>> listMessages({
    required String bookingId,
    String? before,
    int limit = 50,
  }) =>
      remoteDataSource.listMessages(
        bookingId: bookingId,
        before: before,
        limit: limit,
      );
}
