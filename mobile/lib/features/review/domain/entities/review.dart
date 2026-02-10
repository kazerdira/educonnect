import 'package:equatable/equatable.dart';

class Review extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String reviewerId;
  final String reviewerName;
  final String? sessionId;
  final String? courseId;
  final String? offeringId;
  final int rating;
  final String? comment;
  final String? response;
  final String createdAt;
  final String updatedAt;

  const Review({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.reviewerId,
    required this.reviewerName,
    this.sessionId,
    this.courseId,
    this.offeringId,
    required this.rating,
    this.comment,
    this.response,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class TeacherReviewSummary extends Equatable {
  final String teacherId;
  final double averageRating;
  final int totalReviews;
  final int rating5Count;
  final int rating4Count;
  final int rating3Count;

  const TeacherReviewSummary({
    required this.teacherId,
    required this.averageRating,
    required this.totalReviews,
    required this.rating5Count,
    required this.rating4Count,
    required this.rating3Count,
  });

  @override
  List<Object?> get props => [teacherId];
}

class TeacherReviewsResult extends Equatable {
  final TeacherReviewSummary summary;
  final List<Review> reviews;

  const TeacherReviewsResult({
    required this.summary,
    required this.reviews,
  });

  @override
  List<Object?> get props => [summary, reviews];
}
