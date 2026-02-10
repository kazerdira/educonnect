import 'package:educonnect/features/review/domain/entities/review.dart';

abstract class ReviewRepository {
  Future<Review> createReview({
    required String teacherId,
    String? sessionId,
    String? courseId,
    String? offeringId,
    required int rating,
    String? comment,
  });

  Future<TeacherReviewsResult> getTeacherReviews(String teacherId);

  Future<Review> respondToReview(String id, {required String responseText});
}
