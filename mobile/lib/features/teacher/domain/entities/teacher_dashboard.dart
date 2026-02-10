import 'package:equatable/equatable.dart';

class TeacherDashboard extends Equatable {
  final dynamic profile;
  final List<SessionBrief> upcomingSessions;
  final dynamic earnings;
  final List<ReviewBrief> recentReviews;

  const TeacherDashboard({
    required this.profile,
    this.upcomingSessions = const [],
    required this.earnings,
    this.recentReviews = const [],
  });

  @override
  List<Object?> get props => [upcomingSessions, recentReviews];
}

class SessionBrief extends Equatable {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final int participantCount;

  const SessionBrief({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.participantCount = 0,
  });

  @override
  List<Object?> get props => [id, title, startTime, status];
}

class ReviewBrief extends Equatable {
  final String id;
  final String reviewerName;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;

  const ReviewBrief({
    required this.id,
    required this.reviewerName,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, rating, reviewerName];
}
