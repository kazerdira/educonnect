import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/course/domain/entities/course.dart';
import 'package:educonnect/features/course/domain/repositories/course_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class CourseEvent extends Equatable {
  const CourseEvent();
  @override
  List<Object?> get props => [];
}

class CoursesListRequested extends CourseEvent {}

class CourseDetailRequested extends CourseEvent {
  final String courseId;
  const CourseDetailRequested({required this.courseId});
  @override
  List<Object?> get props => [courseId];
}

class CreateCourseRequested extends CourseEvent {
  final String title;
  final String? description;
  final String? subjectId;
  final String? levelId;
  final double price;
  final bool isPublished;

  const CreateCourseRequested({
    required this.title,
    this.description,
    this.subjectId,
    this.levelId,
    required this.price,
    this.isPublished = false,
  });

  @override
  List<Object?> get props => [title, price];
}

class UpdateCourseRequested extends CourseEvent {
  final String courseId;
  final String? title;
  final String? description;
  final double? price;
  final bool? isPublished;

  const UpdateCourseRequested({
    required this.courseId,
    this.title,
    this.description,
    this.price,
    this.isPublished,
  });

  @override
  List<Object?> get props => [courseId];
}

class DeleteCourseRequested extends CourseEvent {
  final String courseId;
  const DeleteCourseRequested({required this.courseId});
  @override
  List<Object?> get props => [courseId];
}

class AddChapterRequested extends CourseEvent {
  final String courseId;
  final String title;
  final int order;

  const AddChapterRequested({
    required this.courseId,
    required this.title,
    required this.order,
  });

  @override
  List<Object?> get props => [courseId, title, order];
}

class AddLessonRequested extends CourseEvent {
  final String courseId;
  final String title;
  final String? description;
  final int order;
  final bool isPreview;

  const AddLessonRequested({
    required this.courseId,
    required this.title,
    this.description,
    required this.order,
    this.isPreview = false,
  });

  @override
  List<Object?> get props => [courseId, title, order];
}

class EnrollCourseRequested extends CourseEvent {
  final String courseId;
  const EnrollCourseRequested({required this.courseId});
  @override
  List<Object?> get props => [courseId];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class CourseState extends Equatable {
  const CourseState();
  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}

class CourseLoading extends CourseState {}

class CoursesLoaded extends CourseState {
  final List<Course> courses;
  const CoursesLoaded({required this.courses});
  @override
  List<Object?> get props => [courses];
}

class CourseDetailLoaded extends CourseState {
  final Course course;
  const CourseDetailLoaded({required this.course});
  @override
  List<Object?> get props => [course];
}

class CourseCreated extends CourseState {
  final Course course;
  const CourseCreated({required this.course});
  @override
  List<Object?> get props => [course];
}

class CourseUpdated extends CourseState {
  final Course course;
  const CourseUpdated({required this.course});
  @override
  List<Object?> get props => [course];
}

class CourseDeleted extends CourseState {}

class ChapterAdded extends CourseState {
  final Chapter chapter;
  const ChapterAdded({required this.chapter});
  @override
  List<Object?> get props => [chapter];
}

class LessonAdded extends CourseState {
  final Lesson lesson;
  const LessonAdded({required this.lesson});
  @override
  List<Object?> get props => [lesson];
}

class CourseEnrolled extends CourseState {
  final Enrollment enrollment;
  const CourseEnrolled({required this.enrollment});
  @override
  List<Object?> get props => [enrollment];
}

class CourseError extends CourseState {
  final String message;
  const CourseError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final CourseRepository courseRepository;

  CourseBloc({required this.courseRepository}) : super(CourseInitial()) {
    on<CoursesListRequested>(_onListCourses);
    on<CourseDetailRequested>(_onGetCourse);
    on<CreateCourseRequested>(_onCreateCourse);
    on<UpdateCourseRequested>(_onUpdateCourse);
    on<DeleteCourseRequested>(_onDeleteCourse);
    on<AddChapterRequested>(_onAddChapter);
    on<AddLessonRequested>(_onAddLesson);
    on<EnrollCourseRequested>(_onEnrollCourse);
  }

  Future<void> _onListCourses(
    CoursesListRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final courses = await courseRepository.listCourses();
      emit(CoursesLoaded(courses: courses));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onGetCourse(
    CourseDetailRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final course = await courseRepository.getCourse(event.courseId);
      emit(CourseDetailLoaded(course: course));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateCourse(
    CreateCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final course = await courseRepository.createCourse(
        title: event.title,
        description: event.description,
        subjectId: event.subjectId,
        levelId: event.levelId,
        price: event.price,
        isPublished: event.isPublished,
      );
      emit(CourseCreated(course: course));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdateCourse(
    UpdateCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final course = await courseRepository.updateCourse(
        event.courseId,
        title: event.title,
        description: event.description,
        price: event.price,
        isPublished: event.isPublished,
      );
      emit(CourseUpdated(course: course));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onDeleteCourse(
    DeleteCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      await courseRepository.deleteCourse(event.courseId);
      emit(CourseDeleted());
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onAddChapter(
    AddChapterRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final chapter = await courseRepository.addChapter(
        event.courseId,
        title: event.title,
        order: event.order,
      );
      emit(ChapterAdded(chapter: chapter));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onAddLesson(
    AddLessonRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final lesson = await courseRepository.addLesson(
        event.courseId,
        title: event.title,
        description: event.description,
        order: event.order,
        isPreview: event.isPreview,
      );
      emit(LessonAdded(lesson: lesson));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  Future<void> _onEnrollCourse(
    EnrollCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final enrollment = await courseRepository.enrollCourse(event.courseId);
      emit(CourseEnrolled(enrollment: enrollment));
    } catch (e) {
      emit(CourseError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
