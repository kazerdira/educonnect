import 'package:educonnect/features/admin/domain/entities/admin.dart';

abstract class AdminRepository {
  // ── Users ───────────────────────────────────────────────────
  Future<List<AdminUser>> listUsers();
  Future<AdminUser> getUser(String id);
  Future<void> suspendUser(String id,
      {required String reason, String? duration});
  Future<void> unsuspendUser(String id);

  // ── Verifications ───────────────────────────────────────────
  Future<List<Verification>> listVerifications();
  Future<void> approveVerification(String id);
  Future<void> rejectVerification(String id, {String? note});

  // ── Disputes ────────────────────────────────────────────────
  Future<List<Dispute>> listDisputes();
  Future<void> resolveDispute(String id, {required String resolution});

  // ── Analytics ───────────────────────────────────────────────
  Future<AnalyticsOverview> getAnalyticsOverview();
  Future<RevenueAnalytics> getRevenueAnalytics();

  // ── Subjects & Levels ───────────────────────────────────────
  Future<List<Subject>> updateSubjects(List<Subject> subjects);
  Future<List<Level>> updateLevels(List<Level> levels);
}
