import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/session/domain/entities/session.dart';
import 'package:educonnect/features/session/domain/repositories/session_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class SessionEvent extends Equatable {
  const SessionEvent();
  @override
  List<Object?> get props => [];
}

class SessionsListRequested extends SessionEvent {
  final String? status;
  final int page;

  const SessionsListRequested({this.status, this.page = 1});

  @override
  List<Object?> get props => [status, page];
}

class SessionDetailRequested extends SessionEvent {
  final String sessionId;
  const SessionDetailRequested({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

class CreateSessionRequested extends SessionEvent {
  final String offeringId;
  final String title;
  final String? description;
  final String sessionType;
  final String startTime;
  final String endTime;
  final int maxStudents;
  final double price;

  const CreateSessionRequested({
    required this.offeringId,
    required this.title,
    this.description,
    required this.sessionType,
    required this.startTime,
    required this.endTime,
    required this.maxStudents,
    required this.price,
  });

  @override
  List<Object?> get props =>
      [offeringId, title, sessionType, startTime, endTime];
}

class JoinSessionRequested extends SessionEvent {
  final String sessionId;
  const JoinSessionRequested({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

class CancelSessionRequested extends SessionEvent {
  final String sessionId;
  final String reason;
  const CancelSessionRequested({
    required this.sessionId,
    required this.reason,
  });
  @override
  List<Object?> get props => [sessionId, reason];
}

class RescheduleSessionRequested extends SessionEvent {
  final String sessionId;
  final String startTime;
  final String endTime;

  const RescheduleSessionRequested({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [sessionId, startTime, endTime];
}

class EndSessionRequested extends SessionEvent {
  final String sessionId;
  const EndSessionRequested({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

class SessionInitial extends SessionState {}

class SessionLoading extends SessionState {}

class SessionsLoaded extends SessionState {
  final List<Session> sessions;
  const SessionsLoaded({required this.sessions});
  @override
  List<Object?> get props => [sessions];
}

class SessionDetailLoaded extends SessionState {
  final Session session;
  const SessionDetailLoaded({required this.session});
  @override
  List<Object?> get props => [session];
}

class SessionCreated extends SessionState {
  final Session session;
  const SessionCreated({required this.session});
  @override
  List<Object?> get props => [session];
}

class SessionJoined extends SessionState {
  final JoinSessionResult result;
  const SessionJoined({required this.result});
  @override
  List<Object?> get props => [result];
}

class SessionCancelled extends SessionState {}

class SessionRescheduled extends SessionState {
  final Session session;
  const SessionRescheduled({required this.session});
  @override
  List<Object?> get props => [session];
}

class SessionEnded extends SessionState {}

class SessionError extends SessionState {
  final String message;
  const SessionError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionRepository sessionRepository;

  SessionBloc({required this.sessionRepository}) : super(SessionInitial()) {
    on<SessionsListRequested>(_onListSessions);
    on<SessionDetailRequested>(_onGetSession);
    on<CreateSessionRequested>(_onCreateSession);
    on<JoinSessionRequested>(_onJoinSession);
    on<CancelSessionRequested>(_onCancelSession);
    on<RescheduleSessionRequested>(_onRescheduleSession);
    on<EndSessionRequested>(_onEndSession);
  }

  Future<void> _onListSessions(
    SessionsListRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      final sessions = await sessionRepository.listSessions(
        status: event.status,
        page: event.page,
      );
      emit(SessionsLoaded(sessions: sessions));
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  Future<void> _onGetSession(
    SessionDetailRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      final session = await sessionRepository.getSession(event.sessionId);
      emit(SessionDetailLoaded(session: session));
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateSession(
    CreateSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      final session = await sessionRepository.createSession(
        offeringId: event.offeringId,
        title: event.title,
        description: event.description,
        sessionType: event.sessionType,
        startTime: event.startTime,
        endTime: event.endTime,
        maxStudents: event.maxStudents,
        price: event.price,
      );
      emit(SessionCreated(session: session));
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  Future<void> _onJoinSession(
    JoinSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      final result = await sessionRepository.joinSession(event.sessionId);
      emit(SessionJoined(result: result));
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  Future<void> _onCancelSession(
    CancelSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      await sessionRepository.cancelSession(event.sessionId, event.reason);
      emit(SessionCancelled());
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  Future<void> _onRescheduleSession(
    RescheduleSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      final session = await sessionRepository.rescheduleSession(
        event.sessionId,
        startTime: event.startTime,
        endTime: event.endTime,
      );
      emit(SessionRescheduled(session: session));
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  Future<void> _onEndSession(
    EndSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      await sessionRepository.endSession(event.sessionId);
      emit(SessionEnded());
    } catch (e) {
      emit(SessionError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
