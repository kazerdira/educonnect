import 'package:educonnect/features/teacher/domain/entities/availability_slot.dart';

class AvailabilitySlotModel extends AvailabilitySlot {
  const AvailabilitySlotModel({
    required super.id,
    required super.dayOfWeek,
    required super.startTime,
    required super.endTime,
  });

  factory AvailabilitySlotModel.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotModel(
      id: json['id'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  /// For creating/updating — no id field
  Map<String, dynamic> toInputJson() {
    return {
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}
