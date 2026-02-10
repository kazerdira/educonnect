import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String title;
  final String? description;
  final String sessionType;
  final String startTime;
  final String endTime;
  final int maxStudents;
  final double price;
  final String status;
  final String? roomId;
  final String? recordingUrl;
  final List<ParticipantBrief> participants;

  const Session({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    this.description,
    required this.sessionType,
    required this.startTime,
    required this.endTime,
    required this.maxStudents,
    required this.price,
    required this.status,
    this.roomId,
    this.recordingUrl,
    this.participants = const [],
  });

  @override
  List<Object?> get props => [id];
}

class ParticipantBrief extends Equatable {
  final String userId;
  final String name;
  final String attendance;

  const ParticipantBrief({
    required this.userId,
    required this.name,
    required this.attendance,
  });

  @override
  List<Object?> get props => [userId];
}

class JoinSessionResult extends Equatable {
  final String roomId;
  final String token;
  final String? url;
  final bool isTeacher;

  const JoinSessionResult({
    required this.roomId,
    required this.token,
    this.url,
    required this.isTeacher,
  });

  @override
  List<Object?> get props => [roomId, token];
}
