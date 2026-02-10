import 'package:educonnect/features/review/data/datasources/review_remote_datasource.dart';
import 'package:educonnect/features/review/domain/entities/review.dart';
import 'package:educonnect/features/review/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource remoteDataSource;

  ReviewRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Review> createReview({
    required String teacherId,
    String? sessionId,
    String? courseId,
    String? offeringId,
    required int rating,
    String? comment,
  }) =>
      remoteDataSource.createReview(
        teacherId: teacherId,
        sessionId: sessionId,
        courseId: courseId,
        offeringId: offeringId,
        rating: rating,
        comment: comment,
      );

  @override
  Future<TeacherReviewsResult> getTeacherReviews(String teacherId) =>
      remoteDataSource.getTeacherReviews(teacherId);

  @override
  Future<Review> respondToReview(String id, {required String responseText}) =>
      remoteDataSource.respondToReview(id, responseText: responseText);
}
