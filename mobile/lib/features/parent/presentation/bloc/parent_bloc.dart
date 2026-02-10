import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/parent/domain/entities/child.dart';
import 'package:educonnect/features/parent/domain/repositories/parent_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class ParentEvent extends Equatable {
  const ParentEvent();
  @override
  List<Object?> get props => [];
}

class ParentDashboardRequested extends ParentEvent {}

class ChildrenListRequested extends ParentEvent {}

class AddChildRequested extends ParentEvent {
  final String firstName;
  final String lastName;
  final String levelCode;
  final String? filiere;
  final String? school;
  final String? dateOfBirth;

  const AddChildRequested({
    required this.firstName,
    required this.lastName,
    required this.levelCode,
    this.filiere,
    this.school,
    this.dateOfBirth,
  });

  @override
  List<Object?> get props => [firstName, lastName, levelCode];
}

class UpdateChildRequested extends ParentEvent {
  final String childId;
  final String? firstName;
  final String? lastName;
  final String? levelCode;
  final String? school;

  const UpdateChildRequested({
    required this.childId,
    this.firstName,
    this.lastName,
    this.levelCode,
    this.school,
  });

  @override
  List<Object?> get props => [childId];
}

class DeleteChildRequested extends ParentEvent {
  final String childId;
  const DeleteChildRequested({required this.childId});
  @override
  List<Object?> get props => [childId];
}

class ChildProgressRequested extends ParentEvent {
  final String childId;
  const ChildProgressRequested({required this.childId});
  @override
  List<Object?> get props => [childId];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class ParentState extends Equatable {
  const ParentState();
  @override
  List<Object?> get props => [];
}

class ParentInitial extends ParentState {}

class ParentLoading extends ParentState {}

class ParentDashboardLoaded extends ParentState {
  final ParentDashboard dashboard;
  const ParentDashboardLoaded({required this.dashboard});
  @override
  List<Object?> get props => [dashboard];
}

class ChildrenLoaded extends ParentState {
  final List<Child> children;
  const ChildrenLoaded({required this.children});
  @override
  List<Object?> get props => [children];
}

class ChildAdded extends ParentState {
  final Child child;
  const ChildAdded({required this.child});
  @override
  List<Object?> get props => [child];
}

class ChildUpdated extends ParentState {
  final Child child;
  const ChildUpdated({required this.child});
  @override
  List<Object?> get props => [child];
}

class ChildDeleted extends ParentState {}

class ChildProgressLoaded extends ParentState {
  final Map<String, dynamic> progress;
  const ChildProgressLoaded({required this.progress});
  @override
  List<Object?> get props => [progress];
}

class ParentError extends ParentState {
  final String message;
  const ParentError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class ParentBloc extends Bloc<ParentEvent, ParentState> {
  final ParentRepository parentRepository;

  ParentBloc({required this.parentRepository}) : super(ParentInitial()) {
    on<ParentDashboardRequested>(_onDashboard);
    on<ChildrenListRequested>(_onListChildren);
    on<AddChildRequested>(_onAddChild);
    on<UpdateChildRequested>(_onUpdateChild);
    on<DeleteChildRequested>(_onDeleteChild);
    on<ChildProgressRequested>(_onChildProgress);
  }

  Future<void> _onDashboard(
    ParentDashboardRequested event,
    Emitter<ParentState> emit,
  ) async {
    emit(ParentLoading());
    try {
      final dashboard = await parentRepository.getDashboard();
      emit(ParentDashboardLoaded(dashboard: dashboard));
    } catch (e) {
      emit(ParentError(message: _extractError(e)));
    }
  }

  Future<void> _onListChildren(
    ChildrenListRequested event,
    Emitter<ParentState> emit,
  ) async {
    emit(ParentLoading());
    try {
      final children = await parentRepository.listChildren();
      emit(ChildrenLoaded(children: children));
    } catch (e) {
      emit(ParentError(message: _extractError(e)));
    }
  }

  Future<void> _onAddChild(
    AddChildRequested event,
    Emitter<ParentState> emit,
  ) async {
    emit(ParentLoading());
    try {
      final child = await parentRepository.addChild(
        firstName: event.firstName,
        lastName: event.lastName,
        levelCode: event.levelCode,
        filiere: event.filiere,
        school: event.school,
        dateOfBirth: event.dateOfBirth,
      );
      emit(ChildAdded(child: child));
    } catch (e) {
      emit(ParentError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdateChild(
    UpdateChildRequested event,
    Emitter<ParentState> emit,
  ) async {
    emit(ParentLoading());
    try {
      final child = await parentRepository.updateChild(
        event.childId,
        firstName: event.firstName,
        lastName: event.lastName,
        levelCode: event.levelCode,
        school: event.school,
      );
      emit(ChildUpdated(child: child));
    } catch (e) {
      emit(ParentError(message: _extractError(e)));
    }
  }

  Future<void> _onDeleteChild(
    DeleteChildRequested event,
    Emitter<ParentState> emit,
  ) async {
    emit(ParentLoading());
    try {
      await parentRepository.deleteChild(event.childId);
      emit(ChildDeleted());
    } catch (e) {
      emit(ParentError(message: _extractError(e)));
    }
  }

  Future<void> _onChildProgress(
    ChildProgressRequested event,
    Emitter<ParentState> emit,
  ) async {
    emit(ParentLoading());
    try {
      final progress = await parentRepository.getChildProgress(event.childId);
      emit(ChildProgressLoaded(progress: progress));
    } catch (e) {
      emit(ParentError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['error']?.toString() ??
          e.message ??
          'Erreur inconnue';
    }
    return e.toString();
  }
}
