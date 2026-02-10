import 'package:educonnect/features/quiz/data/datasources/quiz_remote_datasource.dart';
import 'package:educonnect/features/quiz/domain/entities/quiz.dart';
import 'package:educonnect/features/quiz/domain/repositories/quiz_repository.dart';

class QuizRepositoryImpl implements QuizRepository {
  final QuizRemoteDataSource remoteDataSource;

  QuizRepositoryImpl({required this.remoteDataSource});

  @override
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
  }) =>
      remoteDataSource.createQuiz(
        courseId: courseId,
        title: title,
        description: description,
        duration: duration,
        maxAttempts: maxAttempts,
        passingScore: passingScore,
        questions: questions,
        status: status,
        chapterId: chapterId,
        lessonId: lessonId,
      );

  @override
  Future<List<Quiz>> listQuizzes() => remoteDataSource.listQuizzes();

  @override
  Future<Quiz> getQuiz(String id) => remoteDataSource.getQuiz(id);

  @override
  Future<QuizAttempt> submitAttempt(
    String quizId, {
    required dynamic answers,
  }) =>
      remoteDataSource.submitAttempt(quizId, answers: answers);

  @override
  Future<QuizResults> getResults(String quizId) =>
      remoteDataSource.getResults(quizId);
}
