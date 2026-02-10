import 'package:educonnect/features/session/data/datasources/session_remote_datasource.dart';
import 'package:educonnect/features/session/domain/entities/session.dart';
import 'package:educonnect/features/session/domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final SessionRemoteDataSource remoteDataSource;

  SessionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Session> createSession({
    required String offeringId,
    required String title,
    String? description,
    required String sessionType,
    required String startTime,
    required String endTime,
    required int maxStudents,
    required double price,
  }) =>
      remoteDataSource.createSession(
        offeringId: offeringId,
        title: title,
        description: description,
        sessionType: sessionType,
        startTime: startTime,
        endTime: endTime,
        maxStudents: maxStudents,
        price: price,
      );

  @override
  Future<List<Session>> listSessions({
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      remoteDataSource.listSessions(status: status, page: page, limit: limit);

  @override
  Future<Session> getSession(String id) => remoteDataSource.getSession(id);

  @override
  Future<JoinSessionResult> joinSession(String id) =>
      remoteDataSource.joinSession(id);

  @override
  Future<void> cancelSession(String id, String reason) =>
      remoteDataSource.cancelSession(id, reason);

  @override
  Future<Session> rescheduleSession(
    String id, {
    required String startTime,
    required String endTime,
  }) =>
      remoteDataSource.rescheduleSession(id,
          startTime: startTime, endTime: endTime);

  @override
  Future<void> endSession(String id) => remoteDataSource.endSession(id);

  @override
  Future<String> getSessionRecording(String id) =>
      remoteDataSource.getSessionRecording(id);
}
