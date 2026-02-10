import 'package:equatable/equatable.dart';

class Offering extends Equatable {
  final String id;
  final String teacherId;
  final String subjectId;
  final String subjectName;
  final String levelId;
  final String levelName;
  final String levelCode;
  final String sessionType;
  final double pricePerHour;
  final int maxStudents;
  final bool freeTrialEnabled;
  final int freeTrialDuration;
  final bool isActive;

  const Offering({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.subjectName,
    required this.levelId,
    required this.levelName,
    this.levelCode = '',
    required this.sessionType,
    required this.pricePerHour,
    this.maxStudents = 1,
    this.freeTrialEnabled = false,
    this.freeTrialDuration = 0,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, teacherId, subjectId, levelId];
}
