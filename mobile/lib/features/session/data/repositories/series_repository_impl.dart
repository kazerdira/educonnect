import 'package:educonnect/features/session/data/datasources/series_remote_datasource.dart';
import 'package:educonnect/features/session/data/models/platform_fee_model.dart';
import 'package:educonnect/features/session/data/models/session_series_model.dart';
import 'package:educonnect/features/session/domain/entities/enrollment.dart';
import 'package:educonnect/features/session/domain/entities/platform_fee.dart';
import 'package:educonnect/features/session/domain/entities/session_series.dart';
import 'package:educonnect/features/session/domain/repositories/series_repository.dart';

class SeriesRepositoryImpl implements SeriesRepository {
  final SeriesRemoteDataSource remoteDataSource;

  SeriesRepositoryImpl({required this.remoteDataSource});

  // ==================== SERIES CRUD ====================

  @override
  Future<SessionSeries> createSeries(CreateSeriesRequest request) =>
      remoteDataSource.createSeries(request);

  @override
  Future<List<SessionSeries>> listMySeries({
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      remoteDataSource.listMySeries(status: status, page: page, limit: limit);

  @override
  Future<SessionSeries> getSeriesDetail(String seriesId) =>
      remoteDataSource.getSeriesDetail(seriesId);

  @override
  Future<SessionSeries> addSessionsToSeries(
    String seriesId,
    AddSessionsRequest request,
  ) =>
      remoteDataSource.addSessionsToSeries(seriesId, request);

  @override
  Future<SessionSeries> finalizeSeries(String seriesId) =>
      remoteDataSource.finalizeSeries(seriesId);

  // ==================== TEACHER ENROLLMENT MANAGEMENT ====================

  @override
  Future<List<EnrollmentBrief>> inviteStudents(
    String seriesId,
    InviteStudentsRequest request,
  ) =>
      remoteDataSource.inviteStudents(seriesId, request);

  @override
  Future<List<Enrollment>> getSeriesRequests(String seriesId) =>
      remoteDataSource.getSeriesRequests(seriesId);

  @override
  Future<Enrollment> acceptRequest(String seriesId, String enrollmentId) =>
      remoteDataSource.acceptRequest(seriesId, enrollmentId);

  @override
  Future<Enrollment> declineRequest(
    String seriesId,
    String enrollmentId, {
    String? reason,
  }) =>
      remoteDataSource.declineRequest(seriesId, enrollmentId, reason: reason);

  @override
  Future<void> removeStudent(
    String seriesId,
    String studentId, {
    String? reason,
  }) =>
      remoteDataSource.removeStudent(seriesId, studentId, reason: reason);

  // ==================== STUDENT ENROLLMENT ====================

  @override
  Future<Enrollment> requestToJoin(String seriesId, {String? message}) =>
      remoteDataSource.requestToJoin(seriesId, message: message);

  @override
  Future<List<Enrollment>> getMyInvitations({
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      remoteDataSource.getMyInvitations(
          status: status, page: page, limit: limit);

  @override
  Future<Enrollment> acceptInvitation(String enrollmentId) =>
      remoteDataSource.acceptInvitation(enrollmentId);

  @override
  Future<Enrollment> declineInvitation(String enrollmentId, {String? reason}) =>
      remoteDataSource.declineInvitation(enrollmentId, reason: reason);

  // ==================== PLATFORM FEES ====================

  @override
  Future<List<PlatformFee>> getPendingFees() =>
      remoteDataSource.getPendingFees();

  @override
  Future<PlatformFee> confirmFeePayment(
    String feeId, {
    required String providerRef,
  }) =>
      remoteDataSource.confirmFeePayment(
        feeId,
        ConfirmFeePaymentRequest(
          providerRef: providerRef,
        ),
      );

  // ==================== BROWSE (FOR STUDENTS) ====================

  @override
  Future<List<SessionSeries>> browseAvailableSeries({
    String? subjectId,
    String? levelId,
    String? sessionType,
    int page = 1,
    int limit = 20,
  }) =>
      remoteDataSource.browseAvailableSeries(
        subjectId: subjectId,
        levelId: levelId,
        sessionType: sessionType,
        page: page,
        limit: limit,
      );
}
