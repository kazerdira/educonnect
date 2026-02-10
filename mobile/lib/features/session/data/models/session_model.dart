import 'package:educonnect/features/session/domain/entities/session.dart';

class SessionModel extends Session {
  const SessionModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    required super.title,
    super.description,
    required super.sessionType,
    required super.startTime,
    required super.endTime,
    required super.maxStudents,
    required super.price,
    required super.status,
    super.roomId,
    super.recordingUrl,
    super.participants,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sessionType: json['session_type'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      maxStudents: (json['max_students'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      roomId: json['room_id'] as String?,
      recordingUrl: json['recording_url'] as String?,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) =>
                  ParticipantBriefModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'title': title,
        'description': description,
        'session_type': sessionType,
        'start_time': startTime,
        'end_time': endTime,
        'max_students': maxStudents,
        'price': price,
        'status': status,
        'room_id': roomId,
        'recording_url': recordingUrl,
      };
}

class ParticipantBriefModel extends ParticipantBrief {
  const ParticipantBriefModel({
    required super.userId,
    required super.name,
    required super.attendance,
  });

  factory ParticipantBriefModel.fromJson(Map<String, dynamic> json) {
    return ParticipantBriefModel(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      attendance: json['attendance'] as String? ?? '',
    );
  }
}

class JoinSessionResultModel extends JoinSessionResult {
  const JoinSessionResultModel({
    required super.roomId,
    required super.token,
    super.url,
    required super.isTeacher,
  });

  factory JoinSessionResultModel.fromJson(Map<String, dynamic> json) {
    return JoinSessionResultModel(
      roomId: json['room_id'] as String? ?? '',
      token: json['token'] as String? ?? '',
      url: json['url'] as String?,
      isTeacher: json['is_teacher'] as bool? ?? false,
    );
  }
}
