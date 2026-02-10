import 'package:educonnect/features/teacher/data/models/teacher_profile_model.dart';
import 'package:educonnect/features/teacher/data/models/earnings_model.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_dashboard.dart';

class TeacherDashboardModel extends TeacherDashboard {
  const TeacherDashboardModel({
    required super.profile,
    super.upcomingSessions,
    required super.earnings,
    super.recentReviews,
  });

  factory TeacherDashboardModel.fromJson(Map<String, dynamic> json) {
    return TeacherDashboardModel(
      profile: TeacherProfileModel.fromJson(
          json['profile'] as Map<String, dynamic>? ?? {}),
      upcomingSessions: (json['upcoming_sessions'] as List<dynamic>?)
              ?.map(
                  (e) => SessionBriefModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      earnings: EarningsModel.fromJson(
          json['earnings'] as Map<String, dynamic>? ?? {}),
      recentReviews: (json['recent_reviews'] as List<dynamic>?)
              ?.map((e) => ReviewBriefModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SessionBriefModel extends SessionBrief {
  const SessionBriefModel({
    required super.id,
    required super.title,
    required super.startTime,
    required super.endTime,
    required super.status,
    super.participantCount,
  });

  factory SessionBriefModel.fromJson(Map<String, dynamic> json) {
    return SessionBriefModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ??
          DateTime.now(),
      endTime: DateTime.tryParse(json['end_time'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? '',
      participantCount: json['participant_count'] as int? ?? 0,
    );
  }
}

class ReviewBriefModel extends ReviewBrief {
  const ReviewBriefModel({
    required super.id,
    required super.reviewerName,
    required super.rating,
    super.reviewText,
    required super.createdAt,
  });

  factory ReviewBriefModel.fromJson(Map<String, dynamic> json) {
    return ReviewBriefModel(
      id: json['id'] as String? ?? '',
      reviewerName: json['reviewer_name'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      reviewText: json['review_text'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
