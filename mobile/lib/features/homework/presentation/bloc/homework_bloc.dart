import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/homework/domain/entities/homework.dart';
import 'package:educonnect/features/homework/domain/repositories/homework_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class HomeworkEvent extends Equatable {
  const HomeworkEvent();
  @override
  List<Object?> get props => [];
}

class HomeworkListRequested extends HomeworkEvent {}

class HomeworkDetailRequested extends HomeworkEvent {
  final String homeworkId;
  const HomeworkDetailRequested({required this.homeworkId});
  @override
  List<Object?> get props => [homeworkId];
}

class CreateHomeworkRequested extends HomeworkEvent {
  final String courseId;
  final String title;
  final String description;
  final String instructions;
  final String dueDate;
  final double maxScore;
  final String? attachmentUrl;
  final String status;
  final String? chapterId;

  const CreateHomeworkRequested({
    required this.courseId,
    required this.title,
    required this.description,
    required this.instructions,
    required this.dueDate,
    required this.maxScore,
    this.attachmentUrl,
    required this.status,
    this.chapterId,
  });

  @override
  List<Object?> get props => [courseId, title, dueDate];
}

class SubmitHomeworkRequested extends HomeworkEvent {
  final String homeworkId;
  final String content;
  final String? attachmentUrl;

  const SubmitHomeworkRequested({
    required this.homeworkId,
    required this.content,
    this.attachmentUrl,
  });

  @override
  List<Object?> get props => [homeworkId, content];
}

class GradeHomeworkRequested extends HomeworkEvent {
  final String homeworkId;
  final double grade;
  final String? feedback;
  final String status;

  const GradeHomeworkRequested({
    required this.homeworkId,
    required this.grade,
    this.feedback,
    required this.status,
  });

  @override
  List<Object?> get props => [homeworkId, grade, status];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class HomeworkState extends Equatable {
  const HomeworkState();
  @override
  List<Object?> get props => [];
}

class HomeworkInitial extends HomeworkState {}

class HomeworkLoading extends HomeworkState {}

class HomeworkListLoaded extends HomeworkState {
  final List<Homework> homeworks;
  const HomeworkListLoaded({required this.homeworks});
  @override
  List<Object?> get props => [homeworks];
}

class HomeworkDetailLoaded extends HomeworkState {
  final Homework homework;
  const HomeworkDetailLoaded({required this.homework});
  @override
  List<Object?> get props => [homework];
}

class HomeworkCreated extends HomeworkState {
  final Homework homework;
  const HomeworkCreated({required this.homework});
  @override
  List<Object?> get props => [homework];
}

class HomeworkSubmitted extends HomeworkState {
  final Submission submission;
  const HomeworkSubmitted({required this.submission});
  @override
  List<Object?> get props => [submission];
}

class HomeworkGraded extends HomeworkState {
  final Submission submission;
  const HomeworkGraded({required this.submission});
  @override
  List<Object?> get props => [submission];
}

class HomeworkError extends HomeworkState {
  final String message;
  const HomeworkError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class HomeworkBloc extends Bloc<HomeworkEvent, HomeworkState> {
  final HomeworkRepository homeworkRepository;

  HomeworkBloc({required this.homeworkRepository}) : super(HomeworkInitial()) {
    on<HomeworkListRequested>(_onListHomework);
    on<HomeworkDetailRequested>(_onGetHomework);
    on<CreateHomeworkRequested>(_onCreateHomework);
    on<SubmitHomeworkRequested>(_onSubmitHomework);
    on<GradeHomeworkRequested>(_onGradeHomework);
  }

  Future<void> _onListHomework(
    HomeworkListRequested event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(HomeworkLoading());
    try {
      final homeworks = await homeworkRepository.listHomework();
      emit(HomeworkListLoaded(homeworks: homeworks));
    } catch (e) {
      emit(HomeworkError(message: _extractError(e)));
    }
  }

  Future<void> _onGetHomework(
    HomeworkDetailRequested event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(HomeworkLoading());
    try {
      final homework = await homeworkRepository.getHomework(event.homeworkId);
      emit(HomeworkDetailLoaded(homework: homework));
    } catch (e) {
      emit(HomeworkError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateHomework(
    CreateHomeworkRequested event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(HomeworkLoading());
    try {
      final homework = await homeworkRepository.createHomework(
        courseId: event.courseId,
        title: event.title,
        description: event.description,
        instructions: event.instructions,
        dueDate: event.dueDate,
        maxScore: event.maxScore,
        attachmentUrl: event.attachmentUrl,
        status: event.status,
        chapterId: event.chapterId,
      );
      emit(HomeworkCreated(homework: homework));
    } catch (e) {
      emit(HomeworkError(message: _extractError(e)));
    }
  }

  Future<void> _onSubmitHomework(
    SubmitHomeworkRequested event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(HomeworkLoading());
    try {
      final submission = await homeworkRepository.submitHomework(
        event.homeworkId,
        content: event.content,
        attachmentUrl: event.attachmentUrl,
      );
      emit(HomeworkSubmitted(submission: submission));
    } catch (e) {
      emit(HomeworkError(message: _extractError(e)));
    }
  }

  Future<void> _onGradeHomework(
    GradeHomeworkRequested event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(HomeworkLoading());
    try {
      final submission = await homeworkRepository.gradeHomework(
        event.homeworkId,
        grade: event.grade,
        feedback: event.feedback,
        status: event.status,
      );
      emit(HomeworkGraded(submission: submission));
    } catch (e) {
      emit(HomeworkError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
