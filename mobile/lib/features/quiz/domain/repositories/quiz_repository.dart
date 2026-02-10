import 'package:educonnect/features/quiz/domain/entities/quiz.dart';

abstract class QuizRepository {
  Future<Quiz> createQuiz({
    required String courseId,
    required String title,
    required String description,
    required int duration,
    required int maxAttempts,
    required double passingScore,
    required List<dynamic> questions,
    String status = 'draft',
    String? chapterId,
    String? lessonId,
  });

  Future<List<Quiz>> listQuizzes();

  Future<Quiz> getQuiz(String id);

  Future<QuizAttempt> submitAttempt(
    String quizId, {
    required dynamic answers,
  });

  Future<QuizResults> getResults(String quizId);
}
