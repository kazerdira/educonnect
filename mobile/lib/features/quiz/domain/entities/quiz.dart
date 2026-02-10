import 'package:equatable/equatable.dart';

class Quiz extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String courseId;
  final String courseName;
  final String title;
  final String description;
  final int duration;
  final int maxAttempts;
  final double passingScore;
  final List<dynamic> questions;
  final String status;
  final String createdAt;
  final String updatedAt;

  const Quiz({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.description,
    required this.duration,
    required this.maxAttempts,
    required this.passingScore,
    this.questions = const [],
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class QuizAttempt extends Equatable {
  final String id;
  final String quizId;
  final String studentId;
  final String studentName;
  final dynamic answers;
  final double score;
  final bool passed;
  final String startedAt;
  final String? completedAt;

  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.studentName,
    this.answers,
    required this.score,
    required this.passed,
    required this.startedAt,
    this.completedAt,
  });

  @override
  List<Object?> get props => [id];
}

class QuizResults extends Equatable {
  final String quizId;
  final int totalAttempts;
  final double averageScore;
  final double passRate;
  final List<QuizAttempt> attempts;

  const QuizResults({
    required this.quizId,
    required this.totalAttempts,
    required this.averageScore,
    required this.passRate,
    this.attempts = const [],
  });

  @override
  List<Object?> get props => [quizId];
}
