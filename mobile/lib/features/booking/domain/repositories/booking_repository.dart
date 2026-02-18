import '../entities/booking_message.dart';
import '../entities/booking_request.dart';

abstract class BookingRepository {
  /// Create a new booking request (student/parent)
  /// If [forChildId] is provided, the booking is made by a parent for their child
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
  });

  /// List booking requests (as student or as teacher)
  Future<List<BookingRequest>> listBookingRequests({
    required String role, // 'as_student' or 'as_teacher'
    String? status,
    int page = 1,
    int limit = 20,
  });

  /// Get a single booking request
  Future<BookingRequest> getBookingRequest(String id);

  /// Accept a booking request (teacher only)
  /// If [existingSeriesId] is set, the student is added to that existing series
  Future<BookingRequest> acceptBookingRequest({
    required String bookingId,
    String? title,
    String? description,
    required double price,
    String? existingSeriesId,
  });

  /// Decline a booking request (teacher only)
  Future<BookingRequest> declineBookingRequest({
    required String bookingId,
    required String reason,
  });

  /// Cancel a booking request (student only, while pending)
  Future<void> cancelBookingRequest(String bookingId);

  /// Send a message in a booking conversation thread
  Future<BookingMessage> sendMessage({
    required String bookingId,
    required String content,
  });

  /// List messages in a booking conversation thread
  Future<List<BookingMessage>> listMessages({
    required String bookingId,
    String? before,
    int limit = 50,
  });
}
