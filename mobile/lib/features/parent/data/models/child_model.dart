import 'package:educonnect/features/parent/domain/entities/child.dart';

class ChildModel extends Child {
  const ChildModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    super.avatarUrl,
    super.levelName,
    super.levelCode,
    super.cycle,
    super.filiere,
    super.school,
    super.dateOfBirth,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      levelName: json['level_name'] as String?,
      levelCode: json['level_code'] as String?,
      cycle: json['cycle'] as String?,
      filiere: json['filiere'] as String?,
      school: json['school'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
    );
  }
}

class ParentDashboardModel extends ParentDashboard {
  const ParentDashboardModel({
    required super.children,
    required super.totalChildren,
    required super.totalSessions,
    required super.upcomingSessions,
  });

  factory ParentDashboardModel.fromJson(Map<String, dynamic> json) {
    return ParentDashboardModel(
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => ChildModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalChildren: (json['total_children'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      upcomingSessions: (json['upcoming_sessions'] as num?)?.toInt() ?? 0,
    );
  }
}
