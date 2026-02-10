import 'package:equatable/equatable.dart';

class Child extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? levelName;
  final String? levelCode;
  final String? cycle;
  final String? filiere;
  final String? school;
  final String? dateOfBirth;

  const Child({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.levelName,
    this.levelCode,
    this.cycle,
    this.filiere,
    this.school,
    this.dateOfBirth,
  });

  @override
  List<Object?> get props => [id];
}

class ParentDashboard extends Equatable {
  final List<Child> children;
  final int totalChildren;
  final int totalSessions;
  final int upcomingSessions;

  const ParentDashboard({
    required this.children,
    required this.totalChildren,
    required this.totalSessions,
    required this.upcomingSessions,
  });

  @override
  List<Object?> get props => [totalChildren, totalSessions];
}
