import 'package:educonnect/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:educonnect/features/admin/data/models/admin_model.dart';
import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource remoteDataSource;

  AdminRepositoryImpl({required this.remoteDataSource});

  // ── Users ───────────────────────────────────────────────────

  @override
  Future<List<AdminUser>> listUsers() => remoteDataSource.listUsers();

  @override
  Future<AdminUser> getUser(String id) => remoteDataSource.getUser(id);

  @override
  Future<void> suspendUser(String id,
          {required String reason, String? duration}) =>
      remoteDataSource.suspendUser(id, reason: reason, duration: duration);

  @override
  Future<void> unsuspendUser(String id) => remoteDataSource.unsuspendUser(id);

  // ── Verifications ───────────────────────────────────────────

  @override
  Future<List<Verification>> listVerifications() =>
      remoteDataSource.listVerifications();

  @override
  Future<void> approveVerification(String id) =>
      remoteDataSource.approveVerification(id);

  @override
  Future<void> rejectVerification(String id, {String? note}) =>
      remoteDataSource.rejectVerification(id, note: note);

  // ── Disputes ────────────────────────────────────────────────

  @override
  Future<List<Dispute>> listDisputes() => remoteDataSource.listDisputes();

  @override
  Future<void> resolveDispute(String id, {required String resolution}) =>
      remoteDataSource.resolveDispute(id, resolution: resolution);

  // ── Analytics ───────────────────────────────────────────────

  @override
  Future<AnalyticsOverview> getAnalyticsOverview() =>
      remoteDataSource.getAnalyticsOverview();

  @override
  Future<RevenueAnalytics> getRevenueAnalytics() =>
      remoteDataSource.getRevenueAnalytics();

  // ── Subjects & Levels ───────────────────────────────────────

  @override
  Future<List<Subject>> updateSubjects(List<Subject> subjects) =>
      remoteDataSource.updateSubjects(
        subjects
            .map((s) => SubjectModel(
                  id: s.id,
                  nameAr: s.nameAr,
                  nameFr: s.nameFr,
                  code: s.code,
                ))
            .toList(),
      );

  @override
  Future<List<Level>> updateLevels(List<Level> levels) =>
      remoteDataSource.updateLevels(
        levels
            .map((l) => LevelModel(
                  id: l.id,
                  nameAr: l.nameAr,
                  nameFr: l.nameFr,
                  code: l.code,
                  cycle: l.cycle,
                ))
            .toList(),
      );
}
