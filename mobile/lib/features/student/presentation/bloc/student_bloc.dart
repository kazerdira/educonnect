import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/student/domain/entities/student.dart';
import 'package:educonnect/features/student/domain/repositories/student_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class StudentEvent extends Equatable {
  const StudentEvent();
  @override
  List<Object?> get props => [];
}

class StudentDashboardRequested extends StudentEvent {}

class StudentProgressRequested extends StudentEvent {}

class StudentEnrollmentsRequested extends StudentEvent {}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class StudentState extends Equatable {
  const StudentState();
  @override
  List<Object?> get props => [];
}

class StudentInitial extends StudentState {}

class StudentLoading extends StudentState {}

class StudentDashboardLoaded extends StudentState {
  final StudentDashboard dashboard;
  final List<StudentSessionBrief> recentSessions;
  final List<StudentEnrollment> enrollments;

  const StudentDashboardLoaded({
    required this.dashboard,
    this.recentSessions = const [],
    this.enrollments = const [],
  });

  @override
  List<Object?> get props => [dashboard, recentSessions, enrollments];
}

class StudentProgressLoaded extends StudentState {
  final List<StudentSessionBrief> sessions;
  const StudentProgressLoaded({required this.sessions});
  @override
  List<Object?> get props => [sessions];
}

class StudentEnrollmentsLoaded extends StudentState {
  final List<StudentEnrollment> enrollments;
  const StudentEnrollmentsLoaded({required this.enrollments});
  @override
  List<Object?> get props => [enrollments];
}

class StudentError extends StudentState {
  final String message;
  const StudentError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final StudentRepository studentRepository;

  StudentBloc({required this.studentRepository}) : super(StudentInitial()) {
    on<StudentDashboardRequested>(_onDashboardRequested);
    on<StudentProgressRequested>(_onProgressRequested);
    on<StudentEnrollmentsRequested>(_onEnrollmentsRequested);
  }

  Future<void> _onDashboardRequested(
    StudentDashboardRequested event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final dashboard = await studentRepository.getDashboard();

      List<StudentSessionBrief> recentSessions = [];
      List<StudentEnrollment> enrollments = [];

      try {
        recentSessions = await studentRepository.getProgress();
      } catch (_) {
        // progress endpoint may fail – still show dashboard
      }

      try {
        enrollments = await studentRepository.getEnrollments();
      } catch (_) {
        // enrollments endpoint may fail – still show dashboard
      }

      emit(StudentDashboardLoaded(
        dashboard: dashboard,
        recentSessions: recentSessions,
        enrollments: enrollments,
      ));
    } catch (e) {
      emit(StudentError(message: _extractError(e)));
    }
  }

  Future<void> _onProgressRequested(
    StudentProgressRequested event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final sessions = await studentRepository.getProgress();
      emit(StudentProgressLoaded(sessions: sessions));
    } catch (e) {
      emit(StudentError(message: _extractError(e)));
    }
  }

  Future<void> _onEnrollmentsRequested(
    StudentEnrollmentsRequested event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final enrollments = await studentRepository.getEnrollments();
      emit(StudentEnrollmentsLoaded(enrollments: enrollments));
    } catch (e) {
      emit(StudentError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('DioException')) {
      final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(msg);
      if (match != null) return match.group(1)!;
      final msgMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(msg);
      if (msgMatch != null) return msgMatch.group(1)!;
    }
    if (e is Exception) {
      return msg.replaceFirst('Exception: ', '');
    }
    return 'Une erreur est survenue';
  }
}
