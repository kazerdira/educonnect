import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/session/data/models/session_model.dart';

class SessionRemoteDataSource {
  final ApiClient apiClient;

  SessionRemoteDataSource({required this.apiClient});

  /// POST /sessions
  Future<SessionModel> createSession({
    required String offeringId,
    required String title,
    String? description,
    required String sessionType,
    required String startTime,
    required String endTime,
    required int maxStudents,
    required double price,
  }) async {
    final response = await apiClient.post(
      ApiConstants.sessions,
      data: {
        'offering_id': offeringId,
        'title': title,
        if (description != null) 'description': description,
        'session_type': sessionType,
        'start_time': startTime,
        'end_time': endTime,
        'max_students': maxStudents,
        'price': price,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createSession');
    return SessionModel.fromJson(data);
  }

  /// GET /sessions?status=...&page=...&limit=...
  Future<List<SessionModel>> listSessions({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get(
      ApiConstants.sessions,
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /sessions/:id
  Future<SessionModel> getSession(String id) async {
    final response = await apiClient.get(ApiConstants.sessionDetail(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Session $id not found');
    return SessionModel.fromJson(data);
  }

  /// POST /sessions/:id/join
  Future<JoinSessionResultModel> joinSession(String id) async {
    final response = await apiClient.post(ApiConstants.joinSession(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from joinSession');
    return JoinSessionResultModel.fromJson(data);
  }

  /// POST /sessions/:id/cancel
  Future<void> cancelSession(String id, String reason) async {
    await apiClient.post(
      ApiConstants.cancelSession(id),
      data: {'reason': reason},
    );
  }

  /// PUT /sessions/:id/reschedule
  Future<SessionModel> rescheduleSession(
    String id, {
    required String startTime,
    required String endTime,
  }) async {
    final response = await apiClient.put(
      ApiConstants.rescheduleSession(id),
      data: {
        'start_time': startTime,
        'end_time': endTime,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('No data returned from rescheduleSession');
    return SessionModel.fromJson(data);
  }

  /// POST /sessions/:id/end
  Future<void> endSession(String id) async {
    await apiClient.post(ApiConstants.endSession(id));
  }

  /// GET /sessions/:id/recording
  Future<String> getSessionRecording(String id) async {
    final response = await apiClient.get(ApiConstants.sessionRecording(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    return data?['recording_url'] as String? ?? '';
  }
}
