import 'package:educonnect/features/review/domain/entities/review.dart';

class ReviewModel extends Review {
  const ReviewModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    required super.reviewerId,
    required super.reviewerName,
    super.sessionId,
    super.courseId,
    super.offeringId,
    required super.rating,
    super.comment,
    super.response,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      reviewerId: json['reviewer_id'] as String? ?? '',
      reviewerName: json['reviewer_name'] as String? ?? '',
      sessionId: json['session_id'] as String?,
      courseId: json['course_id'] as String?,
      offeringId: json['offering_id'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      response: json['response'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'reviewer_id': reviewerId,
        'reviewer_name': reviewerName,
        if (sessionId != null) 'session_id': sessionId,
        if (courseId != null) 'course_id': courseId,
        if (offeringId != null) 'offering_id': offeringId,
        'rating': rating,
        if (comment != null) 'comment': comment,
        if (response != null) 'response': response,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class TeacherReviewSummaryModel extends TeacherReviewSummary {
  const TeacherReviewSummaryModel({
    required super.teacherId,
    required super.averageRating,
    required super.totalReviews,
    required super.rating5Count,
    required super.rating4Count,
    required super.rating3Count,
  });

  factory TeacherReviewSummaryModel.fromJson(Map<String, dynamic> json) {
    return TeacherReviewSummaryModel(
      teacherId: json['teacher_id'] as String? ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      rating5Count: (json['rating_5_count'] as num?)?.toInt() ?? 0,
      rating4Count: (json['rating_4_count'] as num?)?.toInt() ?? 0,
      rating3Count: (json['rating_3_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TeacherReviewsResultModel extends TeacherReviewsResult {
  const TeacherReviewsResultModel({
    required super.summary,
    required super.reviews,
  });

  factory TeacherReviewsResultModel.fromJson(Map<String, dynamic> json) {
    return TeacherReviewsResultModel(
      summary: TeacherReviewSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
