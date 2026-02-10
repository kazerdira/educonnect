import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/review/data/models/review_model.dart';

class ReviewRemoteDataSource {
  final ApiClient apiClient;

  ReviewRemoteDataSource({required this.apiClient});

  /// POST /reviews
  Future<ReviewModel> createReview({
    required String teacherId,
    String? sessionId,
    String? courseId,
    String? offeringId,
    required int rating,
    String? comment,
  }) async {
    final response = await apiClient.post(
      ApiConstants.reviews,
      data: {
        'teacher_id': teacherId,
        if (sessionId != null) 'session_id': sessionId,
        if (courseId != null) 'course_id': courseId,
        if (offeringId != null) 'offering_id': offeringId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createReview');
    return ReviewModel.fromJson(data);
  }

  /// GET /reviews/teacher/:teacherId
  Future<TeacherReviewsResultModel> getTeacherReviews(String teacherId) async {
    final response =
        await apiClient.get(ApiConstants.teacherReviews(teacherId));
    final data = response.data['data'] as Map<String, dynamic>?;
    return TeacherReviewsResultModel.fromJson(data ?? {});
  }

  /// POST /reviews/:id/respond
  Future<ReviewModel> respondToReview(String id,
      {required String responseText}) async {
    final response = await apiClient.post(
      ApiConstants.respondToReview(id),
      data: {'response': responseText},
    );
    return ReviewModel.fromJson(response.data['data']);
  }
}
