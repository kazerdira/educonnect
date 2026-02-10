import 'package:educonnect/features/teacher/data/datasources/teacher_remote_datasource.dart';
import 'package:educonnect/features/teacher/data/models/availability_slot_model.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_profile.dart';
import 'package:educonnect/features/teacher/domain/entities/offering.dart';
import 'package:educonnect/features/teacher/domain/entities/availability_slot.dart';
import 'package:educonnect/features/teacher/domain/entities/earnings.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_dashboard.dart';
import 'package:educonnect/features/teacher/domain/repositories/teacher_repository.dart';

class TeacherRepositoryImpl implements TeacherRepository {
  final TeacherRemoteDataSource remoteDataSource;

  TeacherRepositoryImpl({required this.remoteDataSource});

  @override
  Future<TeacherProfile> getTeacherProfile(String teacherId) {
    return remoteDataSource.getTeacherProfile(teacherId);
  }

  @override
  Future<List<TeacherProfile>> listTeachers({int page = 1, int limit = 20}) {
    return remoteDataSource.listTeachers(page: page, limit: limit);
  }

  @override
  Future<TeacherProfile> updateProfile({
    String? bio,
    int? experienceYears,
    List<String>? specializations,
  }) {
    return remoteDataSource.updateProfile(
      bio: bio,
      experienceYears: experienceYears,
      specializations: specializations,
    );
  }

  @override
  Future<TeacherDashboard> getDashboard() {
    return remoteDataSource.getDashboard();
  }

  @override
  Future<List<Offering>> listOfferings() {
    return remoteDataSource.listOfferings();
  }

  @override
  Future<Offering> createOffering({
    required String subjectId,
    required String levelId,
    required String sessionType,
    required double pricePerHour,
    int? maxStudents,
    bool freeTrialEnabled = false,
    int freeTrialDuration = 0,
  }) {
    return remoteDataSource.createOffering(
      subjectId: subjectId,
      levelId: levelId,
      sessionType: sessionType,
      pricePerHour: pricePerHour,
      maxStudents: maxStudents,
      freeTrialEnabled: freeTrialEnabled,
      freeTrialDuration: freeTrialDuration,
    );
  }

  @override
  Future<Offering> updateOffering({
    required String offeringId,
    double? pricePerHour,
    int? maxStudents,
    bool? freeTrialEnabled,
    bool? isActive,
  }) {
    return remoteDataSource.updateOffering(
      offeringId: offeringId,
      pricePerHour: pricePerHour,
      maxStudents: maxStudents,
      freeTrialEnabled: freeTrialEnabled,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteOffering(String offeringId) {
    return remoteDataSource.deleteOffering(offeringId);
  }

  @override
  Future<List<AvailabilitySlot>> getAvailability(String teacherId) {
    return remoteDataSource.getAvailability(teacherId);
  }

  @override
  Future<List<AvailabilitySlot>> setAvailability(List<AvailabilitySlot> slots) {
    final models = slots
        .map((s) => AvailabilitySlotModel(
              id: s.id,
              dayOfWeek: s.dayOfWeek,
              startTime: s.startTime,
              endTime: s.endTime,
            ))
        .toList();
    return remoteDataSource.setAvailability(models);
  }

  @override
  Future<Earnings> getEarnings() {
    return remoteDataSource.getEarnings();
  }
}
