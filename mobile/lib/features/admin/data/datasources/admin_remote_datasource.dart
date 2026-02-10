import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/admin/data/models/admin_model.dart';

class AdminRemoteDataSource {
  final ApiClient apiClient;

  AdminRemoteDataSource({required this.apiClient});

  // ── Users ───────────────────────────────────────────────────

  /// GET /admin/users
  Future<List<AdminUserModel>> listUsers() async {
    final response = await apiClient.get(ApiConstants.adminUsers);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /admin/users/:id
  Future<AdminUserModel> getUser(String id) async {
    final response = await apiClient.get(ApiConstants.adminUserDetail(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('User $id not found');
    return AdminUserModel.fromJson(data);
  }

  /// PUT /admin/users/:id/suspend
  Future<void> suspendUser(
    String id, {
    required String reason,
    String? duration,
  }) async {
    await apiClient.put(
      ApiConstants.adminSuspendUser(id),
      data: {
        'reason': reason,
        if (duration != null) 'duration': duration,
      },
    );
  }

  /// PUT /admin/users/:id/suspend  (unsuspend – empty body)
  Future<void> unsuspendUser(String id) async {
    await apiClient.put(
      ApiConstants.adminSuspendUser(id),
      data: {'unsuspend': true},
    );
  }

  // ── Verifications ───────────────────────────────────────────

  /// GET /admin/verifications
  Future<List<VerificationModel>> listVerifications() async {
    final response = await apiClient.get(ApiConstants.adminVerifications);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => VerificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /admin/verifications/:id/approve
  Future<void> approveVerification(String id) async {
    await apiClient.put(ApiConstants.adminApproveTeacher(id));
  }

  /// PUT /admin/verifications/:id/reject
  Future<void> rejectVerification(String id, {String? note}) async {
    await apiClient.put(
      ApiConstants.adminRejectTeacher(id),
      data: {if (note != null) 'review_note': note},
    );
  }

  // ── Disputes ────────────────────────────────────────────────

  /// GET /admin/disputes
  Future<List<DisputeModel>> listDisputes() async {
    final response = await apiClient.get(ApiConstants.adminDisputes);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => DisputeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /admin/disputes/:id/resolve
  Future<void> resolveDispute(
    String id, {
    required String resolution,
  }) async {
    await apiClient.put(
      ApiConstants.adminResolveDispute(id),
      data: {'resolution': resolution},
    );
  }

  // ── Analytics ───────────────────────────────────────────────

  /// GET /admin/analytics/overview
  Future<AnalyticsOverviewModel> getAnalyticsOverview() async {
    final response = await apiClient.get(ApiConstants.adminAnalyticsOverview);
    final data = response.data['data'] as Map<String, dynamic>?;
    return AnalyticsOverviewModel.fromJson(data ?? {});
  }

  /// GET /admin/analytics/revenue
  Future<RevenueAnalyticsModel> getRevenueAnalytics() async {
    final response = await apiClient.get(ApiConstants.adminAnalyticsRevenue);
    final data = response.data['data'] as Map<String, dynamic>?;
    return RevenueAnalyticsModel.fromJson(data ?? {});
  }

  // ── Subjects & Levels ───────────────────────────────────────

  /// PUT /admin/subjects
  Future<List<SubjectModel>> updateSubjects(List<SubjectModel> subjects) async {
    final response = await apiClient.put(
      ApiConstants.adminUpdateSubjects,
      data: {'subjects': subjects.map((s) => s.toJson()).toList()},
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => SubjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /admin/levels
  Future<List<LevelModel>> updateLevels(List<LevelModel> levels) async {
    final response = await apiClient.put(
      ApiConstants.adminUpdateLevels,
      data: {'levels': levels.map((l) => l.toJson()).toList()},
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
