import 'package:equatable/equatable.dart';

class AvailabilitySlot extends Equatable {
  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  const AvailabilitySlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [id, dayOfWeek, startTime, endTime];
}
