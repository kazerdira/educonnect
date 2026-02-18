import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/session/data/models/enrollment_model.dart';
import 'package:educonnect/features/session/data/models/platform_fee_model.dart';
import 'package:educonnect/features/session/data/models/session_series_model.dart';

class SeriesRemoteDataSource {
  final ApiClient apiClient;

  SeriesRemoteDataSource({required this.apiClient});

  // ==================== SERIES CRUD ====================

  /// POST /sessions/series - Create a new series
  Future<SessionSeriesModel> createSeries(CreateSeriesRequest request) async {
    final response = await apiClient.post(
      ApiConstants.sessionSeries,
      data: request.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createSeries');
    return SessionSeriesModel.fromJson(data);
  }

  /// GET /sessions/series - List teacher's series
  Future<List<SessionSeriesModel>> listMySeries({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get(
      ApiConstants.sessionSeries,
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => SessionSeriesModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /sessions/series/:id - Get series details
  Future<SessionSeriesModel> getSeriesDetail(String seriesId) async {
    final response = await apiClient.get(ApiConstants.seriesDetail(seriesId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Series $seriesId not found');
    return SessionSeriesModel.fromJson(data);
  }

  /// POST /sessions/series/:id/sessions - Add sessions to series
  Future<SessionSeriesModel> addSessionsToSeries(
    String seriesId,
    AddSessionsRequest request,
  ) async {
    final response = await apiClient.post(
      ApiConstants.addSessionsToSeries(seriesId),
      data: request.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('No data returned from addSessionsToSeries');
    return SessionSeriesModel.fromJson(data);
  }

  /// POST /sessions/series/:id/finalize - Finalize series
  Future<SessionSeriesModel> finalizeSeries(String seriesId) async {
    final response =
        await apiClient.post(ApiConstants.finalizeSeries(seriesId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from finalizeSeries');
    return SessionSeriesModel.fromJson(data);
  }

  // ==================== TEACHER ENROLLMENT MANAGEMENT ====================

  /// POST /sessions/series/:id/invite - Invite students
  Future<List<EnrollmentBriefModel>> inviteStudents(
    String seriesId,
    InviteStudentsRequest request,
  ) async {
    final response = await apiClient.post(
      ApiConstants.inviteToSeries(seriesId),
      data: request.toJson(),
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => EnrollmentBriefModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /sessions/series/:id/requests - Get join requests for a series
  Future<List<EnrollmentModel>> getSeriesRequests(String seriesId) async {
    final response = await apiClient.get(ApiConstants.seriesRequests(seriesId));
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => EnrollmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /sessions/series/:id/requests/:enrollmentId/accept
  Future<EnrollmentModel> acceptRequest(
    String seriesId,
    String enrollmentId,
  ) async {
    final response =
        await apiClient.put(ApiConstants.acceptRequest(seriesId, enrollmentId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from acceptRequest');
    return EnrollmentModel.fromJson(data);
  }

  /// PUT /sessions/series/:id/requests/:enrollmentId/decline
  Future<EnrollmentModel> declineRequest(
    String seriesId,
    String enrollmentId, {
    String? reason,
  }) async {
    final response = await apiClient.put(
      ApiConstants.declineRequest(seriesId, enrollmentId),
      data: reason != null ? {'reason': reason} : null,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from declineRequest');
    return EnrollmentModel.fromJson(data);
  }

  /// DELETE /sessions/series/:id/students/:studentId - Remove student
  Future<void> removeStudent(
    String seriesId,
    String studentId, {
    String? reason,
  }) async {
    await apiClient.delete(
      ApiConstants.removeStudent(seriesId, studentId),
      data: reason != null ? {'reason': reason} : null,
    );
  }

  // ==================== STUDENT ENROLLMENT ====================

  /// POST /sessions/series/:id/request - Request to join
  Future<EnrollmentModel> requestToJoin(
    String seriesId, {
    String? message,
  }) async {
    final response = await apiClient.post(
      ApiConstants.requestToJoinSeries(seriesId),
      data: message != null ? {'message': message} : null,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from requestToJoin');
    return EnrollmentModel.fromJson(data);
  }

  /// GET /invitations - Get student's invitations
  Future<List<EnrollmentModel>> getMyInvitations({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get(
      ApiConstants.invitations,
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => EnrollmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /invitations/:id/accept - Accept invitation
  Future<EnrollmentModel> acceptInvitation(String enrollmentId) async {
    final response =
        await apiClient.post(ApiConstants.acceptInvitation(enrollmentId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from acceptInvitation');
    return EnrollmentModel.fromJson(data);
  }

  /// POST /invitations/:id/decline - Decline invitation
  Future<EnrollmentModel> declineInvitation(
    String enrollmentId, {
    String? reason,
  }) async {
    final response = await apiClient.post(
      ApiConstants.declineInvitation(enrollmentId),
      data: reason != null ? {'reason': reason} : null,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('No data returned from declineInvitation');
    return EnrollmentModel.fromJson(data);
  }

  // ==================== PLATFORM FEES ====================

  /// GET /fees - Get pending fees for teacher
  Future<List<PlatformFeeModel>> getPendingFees() async {
    final response = await apiClient.get(ApiConstants.pendingFees);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => PlatformFeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /fees/:id/pay - Confirm fee payment
  Future<PlatformFeeModel> confirmFeePayment(
    String feeId,
    ConfirmFeePaymentRequest request,
  ) async {
    final response = await apiClient.post(
      ApiConstants.confirmFeePayment(feeId),
      data: request.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('No data returned from confirmFeePayment');
    return PlatformFeeModel.fromJson(data);
  }

  // ==================== BROWSE (FOR STUDENTS) ====================

  /// GET /sessions/series/browse - Browse available series (student)
  Future<List<SessionSeriesModel>> browseAvailableSeries({
    String? subjectId,
    String? levelId,
    String? sessionType,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get(
      ApiConstants.browseSeries,
      queryParameters: {
        if (subjectId != null) 'subject_id': subjectId,
        if (levelId != null) 'level_id': levelId,
        if (sessionType != null) 'session_type': sessionType,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => SessionSeriesModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
