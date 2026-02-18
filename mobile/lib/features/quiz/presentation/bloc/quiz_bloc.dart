import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/quiz/domain/entities/quiz.dart';
import 'package:educonnect/features/quiz/domain/repositories/quiz_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class QuizEvent extends Equatable {
  const QuizEvent();
  @override
  List<Object?> get props => [];
}

class QuizListRequested extends QuizEvent {}

class QuizDetailRequested extends QuizEvent {
  final String quizId;
  const QuizDetailRequested({required this.quizId});
  @override
  List<Object?> get props => [quizId];
}

class CreateQuizRequested extends QuizEvent {
  final String courseId;
  final String title;
  final String description;
  final int duration;
  final int maxAttempts;
  final double passingScore;
  final List<dynamic> questions;
  final String status;
  final String? chapterId;
  final String? lessonId;

  const CreateQuizRequested({
    required this.courseId,
    required this.title,
    required this.description,
    required this.duration,
    required this.maxAttempts,
    required this.passingScore,
    required this.questions,
    this.status = 'draft',
    this.chapterId,
    this.lessonId,
  });

  @override
  List<Object?> get props => [courseId, title];
}

class SubmitAttemptRequested extends QuizEvent {
  final String quizId;
  final dynamic answers;

  const SubmitAttemptRequested({
    required this.quizId,
    required this.answers,
  });

  @override
  List<Object?> get props => [quizId];
}

class QuizResultsRequested extends QuizEvent {
  final String quizId;
  const QuizResultsRequested({required this.quizId});
  @override
  List<Object?> get props => [quizId];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class QuizState extends Equatable {
  const QuizState();
  @override
  List<Object?> get props => [];
}

class QuizInitial extends QuizState {}

class QuizLoading extends QuizState {}

class QuizListLoaded extends QuizState {
  final List<Quiz> quizzes;
  const QuizListLoaded({required this.quizzes});
  @override
  List<Object?> get props => [quizzes];
}

class QuizDetailLoaded extends QuizState {
  final Quiz quiz;
  const QuizDetailLoaded({required this.quiz});
  @override
  List<Object?> get props => [quiz];
}

class QuizCreated extends QuizState {
  final Quiz quiz;
  const QuizCreated({required this.quiz});
  @override
  List<Object?> get props => [quiz];
}

class AttemptSubmitted extends QuizState {
  final QuizAttempt attempt;
  const AttemptSubmitted({required this.attempt});
  @override
  List<Object?> get props => [attempt];
}

class QuizResultsLoaded extends QuizState {
  final QuizResults results;
  const QuizResultsLoaded({required this.results});
  @override
  List<Object?> get props => [results];
}

class QuizError extends QuizState {
  final String message;
  const QuizError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class QuizBloc extends Bloc<QuizEvent, QuizState> {
  final QuizRepository quizRepository;

  QuizBloc({required this.quizRepository}) : super(QuizInitial()) {
    on<QuizListRequested>(_onListQuizzes);
    on<QuizDetailRequested>(_onGetQuiz);
    on<CreateQuizRequested>(_onCreateQuiz);
    on<SubmitAttemptRequested>(_onSubmitAttempt);
    on<QuizResultsRequested>(_onGetResults);
  }

  Future<void> _onListQuizzes(
    QuizListRequested event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());
    try {
      final quizzes = await quizRepository.listQuizzes();
      emit(QuizListLoaded(quizzes: quizzes));
    } catch (e) {
      emit(QuizError(message: _extractError(e)));
    }
  }

  Future<void> _onGetQuiz(
    QuizDetailRequested event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());
    try {
      final quiz = await quizRepository.getQuiz(event.quizId);
      emit(QuizDetailLoaded(quiz: quiz));
    } catch (e) {
      emit(QuizError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateQuiz(
    CreateQuizRequested event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());
    try {
      final quiz = await quizRepository.createQuiz(
        courseId: event.courseId,
        title: event.title,
        description: event.description,
        duration: event.duration,
        maxAttempts: event.maxAttempts,
        passingScore: event.passingScore,
        questions: event.questions,
        status: event.status,
        chapterId: event.chapterId,
        lessonId: event.lessonId,
      );
      emit(QuizCreated(quiz: quiz));
    } catch (e) {
      emit(QuizError(message: _extractError(e)));
    }
  }

  Future<void> _onSubmitAttempt(
    SubmitAttemptRequested event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());
    try {
      final attempt = await quizRepository.submitAttempt(
        event.quizId,
        answers: event.answers,
      );
      emit(AttemptSubmitted(attempt: attempt));
    } catch (e) {
      emit(QuizError(message: _extractError(e)));
    }
  }

  Future<void> _onGetResults(
    QuizResultsRequested event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());
    try {
      final results = await quizRepository.getResults(event.quizId);
      emit(QuizResultsLoaded(results: results));
    } catch (e) {
      emit(QuizError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
