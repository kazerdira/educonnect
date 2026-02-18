import 'package:educonnect/features/session/data/models/session_series_model.dart';
import 'package:educonnect/features/session/domain/entities/enrollment.dart';
import 'package:educonnect/features/session/domain/entities/platform_fee.dart';
import 'package:educonnect/features/session/domain/entities/session_series.dart';

/// Repository interface for session series operations
abstract class SeriesRepository {
  // ==================== SERIES CRUD ====================

  /// Create a new series (teacher only)
  Future<SessionSeries> createSeries(CreateSeriesRequest request);

  /// List teacher's own series
  Future<List<SessionSeries>> listMySeries({
    String? status,
    int page = 1,
    int limit = 20,
  });

  /// Get series details
  Future<SessionSeries> getSeriesDetail(String seriesId);

  /// Add sessions to a series (teacher only)
  Future<SessionSeries> addSessionsToSeries(
    String seriesId,
    AddSessionsRequest request,
  );

  /// Finalize series (teacher only, calculates fee)
  Future<SessionSeries> finalizeSeries(String seriesId);

  // ==================== TEACHER ENROLLMENT MANAGEMENT ====================

  /// Invite students to a series
  Future<List<EnrollmentBrief>> inviteStudents(
    String seriesId,
    InviteStudentsRequest request,
  );

  /// Get join requests for a series
  Future<List<Enrollment>> getSeriesRequests(String seriesId);

  /// Accept a student's join request
  Future<Enrollment> acceptRequest(String seriesId, String enrollmentId);

  /// Decline a student's join request
  Future<Enrollment> declineRequest(
    String seriesId,
    String enrollmentId, {
    String? reason,
  });

  /// Remove a student from series
  Future<void> removeStudent(
    String seriesId,
    String studentId, {
    String? reason,
  });

  // ==================== STUDENT ENROLLMENT ====================

  /// Request to join a series (student only)
  Future<Enrollment> requestToJoin(String seriesId, {String? message});

  /// Get student's invitations
  Future<List<Enrollment>> getMyInvitations({
    String? status,
    int page = 1,
    int limit = 20,
  });

  /// Accept an invitation
  Future<Enrollment> acceptInvitation(String enrollmentId);

  /// Decline an invitation
  Future<Enrollment> declineInvitation(String enrollmentId, {String? reason});

  // ==================== PLATFORM FEES ====================

  /// Get pending fees (teacher only)
  Future<List<PlatformFee>> getPendingFees();

  /// Confirm fee payment (teacher only)
  Future<PlatformFee> confirmFeePayment(
    String feeId, {
    required String providerRef,
  });

  // ==================== BROWSE (FOR STUDENTS) ====================

  /// Browse available series to join
  Future<List<SessionSeries>> browseAvailableSeries({
    String? subjectId,
    String? levelId,
    String? sessionType,
    int page = 1,
    int limit = 20,
  });
}
