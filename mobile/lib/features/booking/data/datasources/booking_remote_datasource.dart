import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_constants.dart';
import '../models/booking_message_model.dart';
import '../models/booking_request_model.dart';

abstract class BookingRemoteDataSource {
  Future<BookingRequestModel> createBookingRequest({
    required String teacherId,
    String? offeringId,
    required String sessionType,
    required String requestedDate,
    required String startTime,
    required String endTime,
    String? message,
    String? purpose,
    String? forChildId,
  });

  Future<List<BookingRequestModel>> listBookingRequests({
    required String role,
    String? status,
    int page = 1,
    int limit = 20,
  });

  Future<BookingRequestModel> getBookingRequest(String id);

  Future<BookingRequestModel> acceptBookingRequest({
    required String bookingId,
    String? title,
    String? description,
    required double price,
    String? existingSeriesId,
  });

  Future<BookingRequestModel> declineBookingRequest({
    required String bookingId,
    required String reason,
  });

  Future<void> cancelBookingRequest(String bookingId);

  /// Send a message in a booking conversation thread
  Future<BookingMessageModel> sendMessage({
    required String bookingId,
    required String content,
  });

  /// List messages in a booking conversation thread
  Future<List<BookingMessageModel>> listMessages({
    required String bookingId,
    String? before,
    int limit = 50,
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final ApiClient apiClient;

  BookingRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<BookingRequestModel> createBookingRequest({
    required String teacherId,
    String? offeringId,
    required String sessionType,
    required String requestedDate,
    required String startTime,
    required String endTime,
    String? message,
    String? purpose,
    String? forChildId,
  }) async {
    final response = await apiClient.post(
      ApiConstants.bookings,
      data: {
        'teacher_id': teacherId,
        if (offeringId != null) 'offering_id': offeringId,
        'session_type': sessionType,
        'requested_date': requestedDate,
        'start_time': startTime,
        'end_time': endTime,
        if (message != null && message.isNotEmpty) 'message': message,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (forChildId != null) 'for_child_id': forChildId,
      },
    );
    return BookingRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<BookingRequestModel>> listBookingRequests({
    required String role,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get(
      ApiConstants.bookings,
      queryParameters: {
        'role': role,
        if (status != null) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['bookings'] as List<dynamic>? ?? [];
    return list
        .map((e) => BookingRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BookingRequestModel> getBookingRequest(String id) async {
    final response = await apiClient.get(ApiConstants.bookingDetail(id));
    return BookingRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<BookingRequestModel> acceptBookingRequest({
    required String bookingId,
    String? title,
    String? description,
    required double price,
    String? existingSeriesId,
  }) async {
    final response = await apiClient.put(
      ApiConstants.acceptBooking(bookingId),
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        'price': price,
        if (existingSeriesId != null) 'existing_series_id': existingSeriesId,
      },
    );
    return BookingRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<BookingRequestModel> declineBookingRequest({
    required String bookingId,
    required String reason,
  }) async {
    final response = await apiClient.put(
      ApiConstants.declineBooking(bookingId),
      data: {
        'reason': reason,
      },
    );
    return BookingRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> cancelBookingRequest(String bookingId) async {
    await apiClient.delete(ApiConstants.bookingDetail(bookingId));
  }

  @override
  Future<BookingMessageModel> sendMessage({
    required String bookingId,
    required String content,
  }) async {
    final response = await apiClient.post(
      ApiConstants.bookingMessages(bookingId),
      data: {'content': content},
    );
    return BookingMessageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<BookingMessageModel>> listMessages({
    required String bookingId,
    String? before,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      ApiConstants.bookingMessages(bookingId),
      queryParameters: {
        if (before != null) 'before': before,
        'limit': limit,
      },
    );
    final list = response.data['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => BookingMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
