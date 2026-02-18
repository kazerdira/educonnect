import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/session/data/models/session_series_model.dart';
import 'package:educonnect/features/session/domain/entities/enrollment.dart';
import 'package:educonnect/features/session/domain/entities/platform_fee.dart';
import 'package:educonnect/features/session/domain/entities/session_series.dart';
import 'package:educonnect/features/session/domain/repositories/series_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class SeriesEvent extends Equatable {
  const SeriesEvent();
  @override
  List<Object?> get props => [];
}

// ── Series CRUD Events ──────────────────────────────────────────

class SeriesListRequested extends SeriesEvent {
  final String? status;
  final int page;

  const SeriesListRequested({this.status, this.page = 1});

  @override
  List<Object?> get props => [status, page];
}

class SeriesDetailRequested extends SeriesEvent {
  final String seriesId;
  const SeriesDetailRequested({required this.seriesId});
  @override
  List<Object?> get props => [seriesId];
}

class CreateSeriesRequested extends SeriesEvent {
  final String? offeringId;
  final String? levelId;
  final String? subjectId;
  final String title;
  final String? description;
  final String sessionType;
  final double durationHours;
  final int minStudents;
  final int maxStudents;
  final double pricePerHour;

  const CreateSeriesRequested({
    this.offeringId,
    this.levelId,
    this.subjectId,
    required this.title,
    this.description,
    required this.sessionType,
    required this.durationHours,
    this.minStudents = 1,
    this.maxStudents = 1,
    this.pricePerHour = 0.0,
  });

  @override
  List<Object?> get props => [
        offeringId,
        levelId,
        subjectId,
        title,
        sessionType,
        durationHours,
        maxStudents
      ];
}

class AddSessionsRequested extends SeriesEvent {
  final String seriesId;
  final List<SessionInput> sessions;

  const AddSessionsRequested({
    required this.seriesId,
    required this.sessions,
  });

  @override
  List<Object?> get props => [seriesId, sessions];
}

class FinalizeSeriesRequested extends SeriesEvent {
  final String seriesId;
  const FinalizeSeriesRequested({required this.seriesId});
  @override
  List<Object?> get props => [seriesId];
}

// ── Teacher Enrollment Management Events ────────────────────────

class InviteStudentsRequested extends SeriesEvent {
  final String seriesId;
  final List<String> studentIds;
  final String? message;

  const InviteStudentsRequested({
    required this.seriesId,
    required this.studentIds,
    this.message,
  });

  @override
  List<Object?> get props => [seriesId, studentIds, message];
}

class SeriesRequestsListRequested extends SeriesEvent {
  final String seriesId;
  const SeriesRequestsListRequested({required this.seriesId});
  @override
  List<Object?> get props => [seriesId];
}

class AcceptStudentRequestRequested extends SeriesEvent {
  final String seriesId;
  final String enrollmentId;

  const AcceptStudentRequestRequested({
    required this.seriesId,
    required this.enrollmentId,
  });

  @override
  List<Object?> get props => [seriesId, enrollmentId];
}

class DeclineStudentRequestRequested extends SeriesEvent {
  final String seriesId;
  final String enrollmentId;
  final String? reason;

  const DeclineStudentRequestRequested({
    required this.seriesId,
    required this.enrollmentId,
    this.reason,
  });

  @override
  List<Object?> get props => [seriesId, enrollmentId, reason];
}

class RemoveStudentRequested extends SeriesEvent {
  final String seriesId;
  final String studentId;
  final String? reason;

  const RemoveStudentRequested({
    required this.seriesId,
    required this.studentId,
    this.reason,
  });

  @override
  List<Object?> get props => [seriesId, studentId, reason];
}

// ── Student Enrollment Events ───────────────────────────────────

class RequestToJoinSeriesRequested extends SeriesEvent {
  final String seriesId;
  final String? message;

  const RequestToJoinSeriesRequested({
    required this.seriesId,
    this.message,
  });

  @override
  List<Object?> get props => [seriesId, message];
}

class InvitationsListRequested extends SeriesEvent {
  final String? status;
  final int page;

  const InvitationsListRequested({this.status, this.page = 1});

  @override
  List<Object?> get props => [status, page];
}

class AcceptInvitationRequested extends SeriesEvent {
  final String enrollmentId;
  const AcceptInvitationRequested({required this.enrollmentId});
  @override
  List<Object?> get props => [enrollmentId];
}

class DeclineInvitationRequested extends SeriesEvent {
  final String enrollmentId;
  final String? reason;

  const DeclineInvitationRequested({
    required this.enrollmentId,
    this.reason,
  });

  @override
  List<Object?> get props => [enrollmentId, reason];
}

// ── Platform Fee Events ─────────────────────────────────────────

class PendingFeesRequested extends SeriesEvent {
  const PendingFeesRequested();
}

class ConfirmFeePaymentRequested extends SeriesEvent {
  final String feeId;
  final String providerRef;

  const ConfirmFeePaymentRequested({
    required this.feeId,
    required this.providerRef,
  });

  @override
  List<Object?> get props => [feeId, providerRef];
}

// ── Browse Events (Student) ─────────────────────────────────────

class BrowseSeriesRequested extends SeriesEvent {
  final String? subjectId;
  final String? levelId;
  final String? sessionType;
  final int page;

  const BrowseSeriesRequested({
    this.subjectId,
    this.levelId,
    this.sessionType,
    this.page = 1,
  });

  @override
  List<Object?> get props => [subjectId, levelId, sessionType, page];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class SeriesState extends Equatable {
  const SeriesState();
  @override
  List<Object?> get props => [];
}

class SeriesInitial extends SeriesState {}

class SeriesLoading extends SeriesState {}

// ── Series States ───────────────────────────────────────────────

class SeriesListLoaded extends SeriesState {
  final List<SessionSeries> seriesList;
  const SeriesListLoaded({required this.seriesList});
  @override
  List<Object?> get props => [seriesList];
}

class SeriesDetailLoaded extends SeriesState {
  final SessionSeries series;
  const SeriesDetailLoaded({required this.series});
  @override
  List<Object?> get props => [series];
}

class SeriesCreated extends SeriesState {
  final SessionSeries series;
  const SeriesCreated({required this.series});
  @override
  List<Object?> get props => [series];
}

class SessionsAddedToSeries extends SeriesState {
  final SessionSeries series;
  const SessionsAddedToSeries({required this.series});
  @override
  List<Object?> get props => [series];
}

class SeriesFinalized extends SeriesState {
  final SessionSeries series;
  const SeriesFinalized({required this.series});
  @override
  List<Object?> get props => [series];
}

// ── Enrollment States ───────────────────────────────────────────

class StudentsInvited extends SeriesState {
  final List<EnrollmentBrief> enrollments;
  const StudentsInvited({required this.enrollments});
  @override
  List<Object?> get props => [enrollments];
}

class SeriesRequestsLoaded extends SeriesState {
  final List<Enrollment> requests;
  const SeriesRequestsLoaded({required this.requests});
  @override
  List<Object?> get props => [requests];
}

class RequestAccepted extends SeriesState {
  final Enrollment enrollment;
  const RequestAccepted({required this.enrollment});
  @override
  List<Object?> get props => [enrollment];
}

class RequestDeclined extends SeriesState {
  final Enrollment enrollment;
  const RequestDeclined({required this.enrollment});
  @override
  List<Object?> get props => [enrollment];
}

class StudentRemoved extends SeriesState {}

class JoinRequestSent extends SeriesState {
  final Enrollment enrollment;
  const JoinRequestSent({required this.enrollment});
  @override
  List<Object?> get props => [enrollment];
}

class InvitationsLoaded extends SeriesState {
  final List<Enrollment> invitations;
  const InvitationsLoaded({required this.invitations});
  @override
  List<Object?> get props => [invitations];
}

class InvitationAccepted extends SeriesState {
  final Enrollment enrollment;
  const InvitationAccepted({required this.enrollment});
  @override
  List<Object?> get props => [enrollment];
}

class InvitationDeclined extends SeriesState {
  final Enrollment enrollment;
  const InvitationDeclined({required this.enrollment});
  @override
  List<Object?> get props => [enrollment];
}

// ── Platform Fee States ─────────────────────────────────────────

class PendingFeesLoaded extends SeriesState {
  final List<PlatformFee> fees;
  const PendingFeesLoaded({required this.fees});
  @override
  List<Object?> get props => [fees];
}

class FeePaymentConfirmed extends SeriesState {
  final PlatformFee fee;
  const FeePaymentConfirmed({required this.fee});
  @override
  List<Object?> get props => [fee];
}

// ── Error State ─────────────────────────────────────────────────

class SeriesError extends SeriesState {
  final String message;
  const SeriesError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class SeriesBloc extends Bloc<SeriesEvent, SeriesState> {
  final SeriesRepository seriesRepository;

  SeriesBloc({required this.seriesRepository}) : super(SeriesInitial()) {
    // Series CRUD
    on<SeriesListRequested>(_onListSeries);
    on<SeriesDetailRequested>(_onGetSeriesDetail);
    on<CreateSeriesRequested>(_onCreateSeries);
    on<AddSessionsRequested>(_onAddSessions);
    on<FinalizeSeriesRequested>(_onFinalizeSeries);

    // Teacher enrollment management
    on<InviteStudentsRequested>(_onInviteStudents);
    on<SeriesRequestsListRequested>(_onListSeriesRequests);
    on<AcceptStudentRequestRequested>(_onAcceptRequest);
    on<DeclineStudentRequestRequested>(_onDeclineRequest);
    on<RemoveStudentRequested>(_onRemoveStudent);

    // Student enrollment
    on<RequestToJoinSeriesRequested>(_onRequestToJoin);
    on<InvitationsListRequested>(_onListInvitations);
    on<AcceptInvitationRequested>(_onAcceptInvitation);
    on<DeclineInvitationRequested>(_onDeclineInvitation);

    // Platform fees
    on<PendingFeesRequested>(_onGetPendingFees);
    on<ConfirmFeePaymentRequested>(_onConfirmFeePayment);

    // Browse
    on<BrowseSeriesRequested>(_onBrowseSeries);
  }

  // ── Series CRUD Handlers ──────────────────────────────────────

  Future<void> _onListSeries(
    SeriesListRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final seriesList = await seriesRepository.listMySeries(
        status: event.status,
        page: event.page,
      );
      emit(SeriesListLoaded(seriesList: seriesList));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onGetSeriesDetail(
    SeriesDetailRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final series = await seriesRepository.getSeriesDetail(event.seriesId);
      emit(SeriesDetailLoaded(series: series));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateSeries(
    CreateSeriesRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final series = await seriesRepository.createSeries(
        CreateSeriesRequest(
          offeringId: event.offeringId,
          levelId: event.levelId,
          subjectId: event.subjectId,
          title: event.title,
          description: event.description,
          sessionType: event.sessionType,
          durationHours: event.durationHours,
          minStudents: event.minStudents,
          maxStudents: event.maxStudents,
          pricePerHour: event.pricePerHour,
        ),
      );
      emit(SeriesCreated(series: series));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onAddSessions(
    AddSessionsRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final series = await seriesRepository.addSessionsToSeries(
        event.seriesId,
        AddSessionsRequest(sessions: event.sessions),
      );
      emit(SessionsAddedToSeries(series: series));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onFinalizeSeries(
    FinalizeSeriesRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final series = await seriesRepository.finalizeSeries(event.seriesId);
      emit(SeriesFinalized(series: series));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  // ── Teacher Enrollment Handlers ───────────────────────────────

  Future<void> _onInviteStudents(
    InviteStudentsRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final enrollments = await seriesRepository.inviteStudents(
        event.seriesId,
        InviteStudentsRequest(
          studentIds: event.studentIds,
          message: event.message,
        ),
      );
      emit(StudentsInvited(enrollments: enrollments));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onListSeriesRequests(
    SeriesRequestsListRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final requests = await seriesRepository.getSeriesRequests(event.seriesId);
      emit(SeriesRequestsLoaded(requests: requests));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onAcceptRequest(
    AcceptStudentRequestRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final enrollment = await seriesRepository.acceptRequest(
        event.seriesId,
        event.enrollmentId,
      );
      emit(RequestAccepted(enrollment: enrollment));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onDeclineRequest(
    DeclineStudentRequestRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final enrollment = await seriesRepository.declineRequest(
        event.seriesId,
        event.enrollmentId,
        reason: event.reason,
      );
      emit(RequestDeclined(enrollment: enrollment));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onRemoveStudent(
    RemoveStudentRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      await seriesRepository.removeStudent(
        event.seriesId,
        event.studentId,
        reason: event.reason,
      );
      emit(StudentRemoved());
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  // ── Student Enrollment Handlers ───────────────────────────────

  Future<void> _onRequestToJoin(
    RequestToJoinSeriesRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final enrollment = await seriesRepository.requestToJoin(
        event.seriesId,
        message: event.message,
      );
      emit(JoinRequestSent(enrollment: enrollment));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onListInvitations(
    InvitationsListRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final invitations = await seriesRepository.getMyInvitations(
        status: event.status,
        page: event.page,
      );
      emit(InvitationsLoaded(invitations: invitations));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onAcceptInvitation(
    AcceptInvitationRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final enrollment =
          await seriesRepository.acceptInvitation(event.enrollmentId);
      emit(InvitationAccepted(enrollment: enrollment));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onDeclineInvitation(
    DeclineInvitationRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final enrollment = await seriesRepository.declineInvitation(
        event.enrollmentId,
        reason: event.reason,
      );
      emit(InvitationDeclined(enrollment: enrollment));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  // ── Platform Fee Handlers ─────────────────────────────────────

  Future<void> _onGetPendingFees(
    PendingFeesRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final fees = await seriesRepository.getPendingFees();
      emit(PendingFeesLoaded(fees: fees));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  Future<void> _onConfirmFeePayment(
    ConfirmFeePaymentRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final fee = await seriesRepository.confirmFeePayment(
        event.feeId,
        providerRef: event.providerRef,
      );
      emit(FeePaymentConfirmed(fee: fee));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  // ── Browse Handler ────────────────────────────────────────────

  Future<void> _onBrowseSeries(
    BrowseSeriesRequested event,
    Emitter<SeriesState> emit,
  ) async {
    emit(SeriesLoading());
    try {
      final seriesList = await seriesRepository.browseAvailableSeries(
        subjectId: event.subjectId,
        levelId: event.levelId,
        sessionType: event.sessionType,
        page: event.page,
      );
      emit(SeriesListLoaded(seriesList: seriesList));
    } catch (e) {
      emit(SeriesError(message: _extractError(e)));
    }
  }

  // ── Error Extraction ──────────────────────────────────────────

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
