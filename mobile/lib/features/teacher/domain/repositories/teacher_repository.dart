import 'package:educonnect/features/teacher/domain/entities/teacher_profile.dart';
import 'package:educonnect/features/teacher/domain/entities/offering.dart';
import 'package:educonnect/features/teacher/domain/entities/availability_slot.dart';
import 'package:educonnect/features/teacher/domain/entities/earnings.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_dashboard.dart';

abstract class TeacherRepository {
  // Profile
  Future<TeacherProfile> getTeacherProfile(String teacherId);
  Future<List<TeacherProfile>> listTeachers({int page, int limit});
  Future<TeacherProfile> updateProfile({
    String? bio,
    int? experienceYears,
    List<String>? specializations,
  });

  // Dashboard
  Future<TeacherDashboard> getDashboard();

  // Offerings
  Future<List<Offering>> listOfferings();
  Future<List<Offering>> getTeacherOfferings(
      String teacherId); // Public offerings
  Future<Offering> createOffering({
    required String subjectId,
    required String levelId,
    required String sessionType,
    required double pricePerHour,
    int? maxStudents,
    bool freeTrialEnabled,
    int freeTrialDuration,
  });
  Future<Offering> updateOffering({
    required String offeringId,
    double? pricePerHour,
    int? maxStudents,
    bool? freeTrialEnabled,
    bool? isActive,
  });
  Future<void> deleteOffering(String offeringId);

  // Availability
  Future<List<AvailabilitySlot>> getAvailability(String teacherId);
  Future<List<AvailabilitySlot>> setAvailability(List<AvailabilitySlot> slots);

  // Earnings
  Future<Earnings> getEarnings();
}
