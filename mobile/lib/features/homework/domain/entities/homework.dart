import 'package:equatable/equatable.dart';

class Homework extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String courseId;
  final String courseName;
  final String title;
  final String description;
  final String instructions;
  final String dueDate;
  final double maxScore;
  final String? attachmentUrl;
  final String status;
  final int submissionCount;
  final String createdAt;
  final String updatedAt;

  const Homework({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.description,
    required this.instructions,
    required this.dueDate,
    required this.maxScore,
    this.attachmentUrl,
    required this.status,
    required this.submissionCount,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class Submission extends Equatable {
  final String id;
  final String homeworkId;
  final String studentId;
  final String studentName;
  final String content;
  final String? attachmentUrl;
  final double? grade;
  final String? feedback;
  final String status;
  final String submittedAt;
  final String? gradedAt;
  final String updatedAt;

  const Submission({
    required this.id,
    required this.homeworkId,
    required this.studentId,
    required this.studentName,
    required this.content,
    this.attachmentUrl,
    this.grade,
    this.feedback,
    required this.status,
    required this.submittedAt,
    this.gradedAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}
