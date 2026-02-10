import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/homework/data/models/homework_model.dart';

class HomeworkRemoteDataSource {
  final ApiClient apiClient;

  HomeworkRemoteDataSource({required this.apiClient});

  /// POST /homework
  Future<HomeworkModel> createHomework({
    required String courseId,
    required String title,
    required String description,
    required String instructions,
    required String dueDate,
    required double maxScore,
    String? attachmentUrl,
    required String status,
    String? chapterId,
  }) async {
    final response = await apiClient.post(
      ApiConstants.homework,
      data: {
        'course_id': courseId,
        'title': title,
        'description': description,
        'instructions': instructions,
        'due_date': dueDate,
        'max_score': maxScore,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        'status': status,
        if (chapterId != null) 'chapter_id': chapterId,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createHomework');
    return HomeworkModel.fromJson(data);
  }

  /// GET /homework
  Future<List<HomeworkModel>> listHomework() async {
    final response = await apiClient.get(ApiConstants.homework);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => HomeworkModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /homework/:id
  Future<HomeworkModel> getHomework(String id) async {
    final response = await apiClient.get(ApiConstants.homeworkDetail(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Homework $id not found');
    return HomeworkModel.fromJson(data);
  }

  /// POST /homework/:id/submit
  Future<SubmissionModel> submitHomework(
    String homeworkId, {
    required String content,
    String? attachmentUrl,
  }) async {
    final response = await apiClient.post(
      ApiConstants.submitHomework(homeworkId),
      data: {
        'content': content,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from submitHomework');
    return SubmissionModel.fromJson(data);
  }

  /// PUT /homework/:id/grade
  Future<SubmissionModel> gradeHomework(
    String homeworkId, {
    required double grade,
    String? feedback,
    required String status,
  }) async {
    final response = await apiClient.put(
      ApiConstants.gradeHomework(homeworkId),
      data: {
        'grade': grade,
        if (feedback != null) 'feedback': feedback,
        'status': status,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from gradeHomework');
    return SubmissionModel.fromJson(data);
  }
}
