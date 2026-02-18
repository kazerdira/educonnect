import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/review/domain/entities/review.dart';
import 'package:educonnect/features/review/domain/repositories/review_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class ReviewEvent extends Equatable {
  const ReviewEvent();
  @override
  List<Object?> get props => [];
}

class TeacherReviewsRequested extends ReviewEvent {
  final String teacherId;
  const TeacherReviewsRequested({required this.teacherId});
  @override
  List<Object?> get props => [teacherId];
}

class CreateReviewRequested extends ReviewEvent {
  final String teacherId;
  final String? sessionId;
  final String? courseId;
  final String? offeringId;
  final int rating;
  final String? comment;

  const CreateReviewRequested({
    required this.teacherId,
    this.sessionId,
    this.courseId,
    this.offeringId,
    required this.rating,
    this.comment,
  });

  @override
  List<Object?> get props => [teacherId, rating];
}

class RespondToReviewRequested extends ReviewEvent {
  final String reviewId;
  final String responseText;
  final String teacherId;

  const RespondToReviewRequested({
    required this.reviewId,
    required this.responseText,
    required this.teacherId,
  });

  @override
  List<Object?> get props => [reviewId, responseText];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class ReviewState extends Equatable {
  const ReviewState();
  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {}

class ReviewLoading extends ReviewState {}

class TeacherReviewsLoaded extends ReviewState {
  final TeacherReviewsResult result;
  const TeacherReviewsLoaded({required this.result});
  @override
  List<Object?> get props => [result];
}

class ReviewCreated extends ReviewState {
  final Review review;
  const ReviewCreated({required this.review});
  @override
  List<Object?> get props => [review];
}

class ReviewResponded extends ReviewState {
  final Review review;
  final String teacherId;
  const ReviewResponded({required this.review, required this.teacherId});
  @override
  List<Object?> get props => [review];
}

class ReviewError extends ReviewState {
  final String message;
  const ReviewError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  final ReviewRepository reviewRepository;

  ReviewBloc({required this.reviewRepository}) : super(ReviewInitial()) {
    on<TeacherReviewsRequested>(_onTeacherReviews);
    on<CreateReviewRequested>(_onCreateReview);
    on<RespondToReviewRequested>(_onRespondToReview);
  }

  Future<void> _onTeacherReviews(
    TeacherReviewsRequested event,
    Emitter<ReviewState> emit,
  ) async {
    emit(ReviewLoading());
    try {
      final result = await reviewRepository.getTeacherReviews(event.teacherId);
      emit(TeacherReviewsLoaded(result: result));
    } catch (e) {
      emit(ReviewError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateReview(
    CreateReviewRequested event,
    Emitter<ReviewState> emit,
  ) async {
    emit(ReviewLoading());
    try {
      final review = await reviewRepository.createReview(
        teacherId: event.teacherId,
        sessionId: event.sessionId,
        courseId: event.courseId,
        offeringId: event.offeringId,
        rating: event.rating,
        comment: event.comment,
      );
      emit(ReviewCreated(review: review));
    } catch (e) {
      emit(ReviewError(message: _extractError(e)));
    }
  }

  Future<void> _onRespondToReview(
    RespondToReviewRequested event,
    Emitter<ReviewState> emit,
  ) async {
    emit(ReviewLoading());
    try {
      final review = await reviewRepository.respondToReview(
        event.reviewId,
        responseText: event.responseText,
      );
      emit(ReviewResponded(review: review, teacherId: event.teacherId));
    } catch (e) {
      emit(ReviewError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
