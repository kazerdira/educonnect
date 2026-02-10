import 'package:educonnect/features/quiz/domain/entities/quiz.dart';

class QuizModel extends Quiz {
  const QuizModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    required super.courseId,
    required super.courseName,
    required super.title,
    required super.description,
    required super.duration,
    required super.maxAttempts,
    required super.passingScore,
    super.questions,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 1,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 0,
      questions: json['questions'] as List<dynamic>? ?? [],
      status: json['status'] as String? ?? 'draft',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'course_id': courseId,
      'course_name': courseName,
      'title': title,
      'description': description,
      'duration': duration,
      'max_attempts': maxAttempts,
      'passing_score': passingScore,
      'questions': questions,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class QuizAttemptModel extends QuizAttempt {
  const QuizAttemptModel({
    required super.id,
    required super.quizId,
    required super.studentId,
    required super.studentName,
    super.answers,
    required super.score,
    required super.passed,
    required super.startedAt,
    super.completedAt,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    return QuizAttemptModel(
      id: json['id'] as String? ?? '',
      quizId: json['quiz_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      answers: json['answers'],
      score: (json['score'] as num?)?.toDouble() ?? 0,
      passed: json['passed'] as bool? ?? false,
      startedAt: json['started_at'] as String? ?? '',
      completedAt: json['completed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'student_id': studentId,
      'student_name': studentName,
      'answers': answers,
      'score': score,
      'passed': passed,
      'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
    };
  }
}

class QuizResultsModel extends QuizResults {
  const QuizResultsModel({
    required super.quizId,
    required super.totalAttempts,
    required super.averageScore,
    required super.passRate,
    super.attempts,
  });

  factory QuizResultsModel.fromJson(Map<String, dynamic> json) {
    return QuizResultsModel(
      quizId: json['quiz_id'] as String? ?? '',
      totalAttempts: (json['total_attempts'] as num?)?.toInt() ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0,
      passRate: (json['pass_rate'] as num?)?.toDouble() ?? 0,
      attempts: (json['attempts'] as List<dynamic>?)
              ?.map((e) => QuizAttemptModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'total_attempts': totalAttempts,
      'average_score': averageScore,
      'pass_rate': passRate,
      'attempts':
          attempts.map((a) => (a as QuizAttemptModel).toJson()).toList(),
    };
  }
}
