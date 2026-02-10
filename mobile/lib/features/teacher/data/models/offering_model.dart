import 'package:educonnect/features/teacher/domain/entities/offering.dart';

class OfferingModel extends Offering {
  const OfferingModel({
    required super.id,
    required super.teacherId,
    required super.subjectId,
    required super.subjectName,
    required super.levelId,
    required super.levelName,
    super.levelCode,
    required super.sessionType,
    required super.pricePerHour,
    super.maxStudents,
    super.freeTrialEnabled,
    super.freeTrialDuration,
    super.isActive,
  });

  factory OfferingModel.fromJson(Map<String, dynamic> json) {
    return OfferingModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      levelId: json['level_id'] as String? ?? '',
      levelName: json['level_name'] as String? ?? '',
      levelCode: json['level_code'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? 'one_on_one',
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      maxStudents: json['max_students'] as int? ?? 1,
      freeTrialEnabled: json['free_trial_enabled'] as bool? ?? false,
      freeTrialDuration: json['free_trial_duration'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'level_id': levelId,
      'level_name': levelName,
      'level_code': levelCode,
      'session_type': sessionType,
      'price_per_hour': pricePerHour,
      'max_students': maxStudents,
      'free_trial_enabled': freeTrialEnabled,
      'free_trial_duration': freeTrialDuration,
      'is_active': isActive,
    };
  }
}
