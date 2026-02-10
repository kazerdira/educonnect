import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/quiz/data/models/quiz_model.dart';

class QuizRemoteDataSource {
  final ApiClient apiClient;

  QuizRemoteDataSource({required this.apiClient});

  /// POST /quizzes
  Future<QuizModel> createQuiz({
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
  }) async {
    final response = await apiClient.post(
      ApiConstants.quizzes,
      data: {
        'course_id': courseId,
        'title': title,
        'description': description,
        'duration': duration,
        'max_attempts': maxAttempts,
        'passing_score': passingScore,
        'questions': questions,
        'status': status,
        if (chapterId != null) 'chapter_id': chapterId,
        if (lessonId != null) 'lesson_id': lessonId,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createQuiz');
    return QuizModel.fromJson(data);
  }

  /// GET /quizzes
  Future<List<QuizModel>> listQuizzes() async {
    final response = await apiClient.get(ApiConstants.quizzes);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => QuizModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /quizzes/:id
  Future<QuizModel> getQuiz(String id) async {
    final response = await apiClient.get(ApiConstants.quizDetail(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Quiz $id not found');
    return QuizModel.fromJson(data);
  }

  /// POST /quizzes/:id/attempt
  Future<QuizAttemptModel> submitAttempt(
    String quizId, {
    required dynamic answers,
  }) async {
    final response = await apiClient.post(
      ApiConstants.attemptQuiz(quizId),
      data: {'answers': answers},
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from submitAttempt');
    return QuizAttemptModel.fromJson(data);
  }

  /// GET /quizzes/:id/results
  Future<QuizResultsModel> getResults(String quizId) async {
    final response = await apiClient.get(ApiConstants.quizResults(quizId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Quiz results not found');
    return QuizResultsModel.fromJson(data);
  }
}
