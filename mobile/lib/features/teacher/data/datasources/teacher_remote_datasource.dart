import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/teacher/data/models/teacher_profile_model.dart';
import 'package:educonnect/features/teacher/data/models/offering_model.dart';
import 'package:educonnect/features/teacher/data/models/availability_slot_model.dart';
import 'package:educonnect/features/teacher/data/models/earnings_model.dart';
import 'package:educonnect/features/teacher/data/models/teacher_dashboard_model.dart';

class TeacherRemoteDataSource {
  final ApiClient apiClient;

  TeacherRemoteDataSource({required this.apiClient});

  // ── Profile ─────────────────────────────────────────────────

  Future<TeacherProfileModel> getTeacherProfile(String teacherId) async {
    final response =
        await apiClient.dio.get(ApiConstants.teacherDetail(teacherId));
    final data = response.data['data'] as Map<String, dynamic>?;
    return TeacherProfileModel.fromJson(data ?? {});
  }

  Future<List<TeacherProfileModel>> listTeachers({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.dio.get(
      ApiConstants.teachers,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => TeacherProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TeacherProfileModel> updateProfile({
    String? bio,
    int? experienceYears,
    List<String>? specializations,
  }) async {
    final response = await apiClient.dio.put(
      ApiConstants.teacherProfile,
      data: {
        if (bio != null) 'bio': bio,
        if (experienceYears != null) 'experience_years': experienceYears,
        if (specializations != null) 'specializations': specializations,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    return TeacherProfileModel.fromJson(data ?? {});
  }

  // ── Dashboard ───────────────────────────────────────────────

  Future<TeacherDashboardModel> getDashboard() async {
    final response = await apiClient.dio.get(ApiConstants.teacherDashboard);
    final data = response.data['data'] as Map<String, dynamic>?;
    return TeacherDashboardModel.fromJson(data ?? {});
  }

  // ── Offerings ───────────────────────────────────────────────

  Future<List<OfferingModel>> listOfferings() async {
    final response = await apiClient.dio.get(ApiConstants.offerings);
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OfferingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OfferingModel> createOffering({
    required String subjectId,
    required String levelId,
    required String sessionType,
    required double pricePerHour,
    int? maxStudents,
    bool freeTrialEnabled = false,
    int freeTrialDuration = 0,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.offerings,
      data: {
        'subject_id': subjectId,
        'level_id': levelId,
        'session_type': sessionType,
        'price_per_hour': pricePerHour,
        if (maxStudents != null) 'max_students': maxStudents,
        'free_trial_enabled': freeTrialEnabled,
        'free_trial_duration': freeTrialDuration,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createOffering');
    return OfferingModel.fromJson(data);
  }

  Future<OfferingModel> updateOffering({
    required String offeringId,
    double? pricePerHour,
    int? maxStudents,
    bool? freeTrialEnabled,
    bool? isActive,
  }) async {
    final response = await apiClient.dio.put(
      ApiConstants.offeringDetail(offeringId),
      data: {
        if (pricePerHour != null) 'price_per_hour': pricePerHour,
        if (maxStudents != null) 'max_students': maxStudents,
        if (freeTrialEnabled != null) 'free_trial_enabled': freeTrialEnabled,
        if (isActive != null) 'is_active': isActive,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from updateOffering');
    return OfferingModel.fromJson(data);
  }

  Future<void> deleteOffering(String offeringId) async {
    await apiClient.dio.delete(ApiConstants.offeringDetail(offeringId));
  }

  // ── Availability ────────────────────────────────────────────

  Future<List<AvailabilitySlotModel>> getAvailability(String teacherId) async {
    final response = await apiClient.dio
        .get('${ApiConstants.teachers}/$teacherId/availability');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AvailabilitySlotModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AvailabilitySlotModel>> setAvailability(
      List<AvailabilitySlotModel> slots) async {
    final response = await apiClient.dio.put(
      ApiConstants.availability,
      data: {
        'slots': slots.map((s) => s.toInputJson()).toList(),
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AvailabilitySlotModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Earnings ────────────────────────────────────────────────

  Future<EarningsModel> getEarnings() async {
    final response = await apiClient.dio.get(ApiConstants.earnings);
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) return const EarningsModel();
    return EarningsModel.fromJson(data);
  }
}
