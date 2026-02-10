import 'package:educonnect/features/session/domain/entities/session.dart';

abstract class SessionRepository {
  Future<Session> createSession({
    required String offeringId,
    required String title,
    String? description,
    required String sessionType,
    required String startTime,
    required String endTime,
    required int maxStudents,
    required double price,
  });

  Future<List<Session>> listSessions({
    String? status,
    int page = 1,
    int limit = 20,
  });

  Future<Session> getSession(String id);

  Future<JoinSessionResult> joinSession(String id);

  Future<void> cancelSession(String id, String reason);

  Future<Session> rescheduleSession(
    String id, {
    required String startTime,
    required String endTime,
  });

  Future<void> endSession(String id);

  Future<String> getSessionRecording(String id);
}
