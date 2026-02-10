import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_profile.dart';
import 'package:educonnect/features/teacher/domain/entities/offering.dart';
import 'package:educonnect/features/teacher/domain/entities/availability_slot.dart';
import 'package:educonnect/features/teacher/domain/entities/earnings.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_dashboard.dart';
import 'package:educonnect/features/teacher/domain/repositories/teacher_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class TeacherEvent extends Equatable {
  const TeacherEvent();
  @override
  List<Object?> get props => [];
}

class TeacherDashboardRequested extends TeacherEvent {}

class TeacherProfileRequested extends TeacherEvent {
  final String teacherId;
  const TeacherProfileRequested({required this.teacherId});
  @override
  List<Object?> get props => [teacherId];
}

class TeacherProfileUpdateRequested extends TeacherEvent {
  final String? bio;
  final int? experienceYears;
  final List<String>? specializations;

  const TeacherProfileUpdateRequested({
    this.bio,
    this.experienceYears,
    this.specializations,
  });
}

class TeacherOfferingsRequested extends TeacherEvent {}

class TeacherOfferingCreateRequested extends TeacherEvent {
  final String subjectId;
  final String levelId;
  final String sessionType;
  final double pricePerHour;
  final int? maxStudents;
  final bool freeTrialEnabled;
  final int freeTrialDuration;

  const TeacherOfferingCreateRequested({
    required this.subjectId,
    required this.levelId,
    required this.sessionType,
    required this.pricePerHour,
    this.maxStudents,
    this.freeTrialEnabled = false,
    this.freeTrialDuration = 0,
  });
}

class TeacherOfferingUpdateRequested extends TeacherEvent {
  final String offeringId;
  final double? pricePerHour;
  final int? maxStudents;
  final bool? freeTrialEnabled;
  final bool? isActive;

  const TeacherOfferingUpdateRequested({
    required this.offeringId,
    this.pricePerHour,
    this.maxStudents,
    this.freeTrialEnabled,
    this.isActive,
  });
}

class TeacherOfferingDeleteRequested extends TeacherEvent {
  final String offeringId;
  const TeacherOfferingDeleteRequested({required this.offeringId});
  @override
  List<Object?> get props => [offeringId];
}

class TeacherAvailabilityRequested extends TeacherEvent {
  final String teacherId;
  const TeacherAvailabilityRequested({required this.teacherId});
  @override
  List<Object?> get props => [teacherId];
}

class TeacherAvailabilityUpdateRequested extends TeacherEvent {
  final List<AvailabilitySlot> slots;
  const TeacherAvailabilityUpdateRequested({required this.slots});
}

class TeacherEarningsRequested extends TeacherEvent {}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class TeacherState extends Equatable {
  const TeacherState();
  @override
  List<Object?> get props => [];
}

class TeacherInitial extends TeacherState {}

class TeacherLoading extends TeacherState {}

class TeacherDashboardLoaded extends TeacherState {
  final TeacherDashboard dashboard;
  const TeacherDashboardLoaded({required this.dashboard});
  @override
  List<Object?> get props => [dashboard];
}

class TeacherProfileLoaded extends TeacherState {
  final TeacherProfile profile;
  const TeacherProfileLoaded({required this.profile});
  @override
  List<Object?> get props => [profile];
}

class TeacherProfileUpdated extends TeacherState {
  final TeacherProfile profile;
  const TeacherProfileUpdated({required this.profile});
  @override
  List<Object?> get props => [profile];
}

class TeacherOfferingsLoaded extends TeacherState {
  final List<Offering> offerings;
  const TeacherOfferingsLoaded({required this.offerings});
  @override
  List<Object?> get props => [offerings];
}

class TeacherOfferingCreated extends TeacherState {
  final Offering offering;
  const TeacherOfferingCreated({required this.offering});
}

class TeacherOfferingUpdated extends TeacherState {
  final Offering offering;
  const TeacherOfferingUpdated({required this.offering});
}

class TeacherOfferingDeleted extends TeacherState {}

class TeacherAvailabilityLoaded extends TeacherState {
  final List<AvailabilitySlot> slots;
  const TeacherAvailabilityLoaded({required this.slots});
  @override
  List<Object?> get props => [slots];
}

class TeacherEarningsLoaded extends TeacherState {
  final Earnings earnings;
  const TeacherEarningsLoaded({required this.earnings});
  @override
  List<Object?> get props => [earnings];
}

class TeacherError extends TeacherState {
  final String message;
  const TeacherError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class TeacherBloc extends Bloc<TeacherEvent, TeacherState> {
  final TeacherRepository teacherRepository;

  TeacherBloc({required this.teacherRepository}) : super(TeacherInitial()) {
    on<TeacherDashboardRequested>(_onDashboardRequested);
    on<TeacherProfileRequested>(_onProfileRequested);
    on<TeacherProfileUpdateRequested>(_onProfileUpdateRequested);
    on<TeacherOfferingsRequested>(_onOfferingsRequested);
    on<TeacherOfferingCreateRequested>(_onOfferingCreateRequested);
    on<TeacherOfferingUpdateRequested>(_onOfferingUpdateRequested);
    on<TeacherOfferingDeleteRequested>(_onOfferingDeleteRequested);
    on<TeacherAvailabilityRequested>(_onAvailabilityRequested);
    on<TeacherAvailabilityUpdateRequested>(_onAvailabilityUpdateRequested);
    on<TeacherEarningsRequested>(_onEarningsRequested);
  }

  Future<void> _onDashboardRequested(
    TeacherDashboardRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final dashboard = await teacherRepository.getDashboard();
      emit(TeacherDashboardLoaded(dashboard: dashboard));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onProfileRequested(
    TeacherProfileRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final profile =
          await teacherRepository.getTeacherProfile(event.teacherId);
      emit(TeacherProfileLoaded(profile: profile));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onProfileUpdateRequested(
    TeacherProfileUpdateRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final profile = await teacherRepository.updateProfile(
        bio: event.bio,
        experienceYears: event.experienceYears,
        specializations: event.specializations,
      );
      emit(TeacherProfileUpdated(profile: profile));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onOfferingsRequested(
    TeacherOfferingsRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final offerings = await teacherRepository.listOfferings();
      emit(TeacherOfferingsLoaded(offerings: offerings));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onOfferingCreateRequested(
    TeacherOfferingCreateRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final offering = await teacherRepository.createOffering(
        subjectId: event.subjectId,
        levelId: event.levelId,
        sessionType: event.sessionType,
        pricePerHour: event.pricePerHour,
        maxStudents: event.maxStudents,
        freeTrialEnabled: event.freeTrialEnabled,
        freeTrialDuration: event.freeTrialDuration,
      );
      emit(TeacherOfferingCreated(offering: offering));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onOfferingUpdateRequested(
    TeacherOfferingUpdateRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final offering = await teacherRepository.updateOffering(
        offeringId: event.offeringId,
        pricePerHour: event.pricePerHour,
        maxStudents: event.maxStudents,
        freeTrialEnabled: event.freeTrialEnabled,
        isActive: event.isActive,
      );
      emit(TeacherOfferingUpdated(offering: offering));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onOfferingDeleteRequested(
    TeacherOfferingDeleteRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      await teacherRepository.deleteOffering(event.offeringId);
      emit(TeacherOfferingDeleted());
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onAvailabilityRequested(
    TeacherAvailabilityRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final slots = await teacherRepository.getAvailability(event.teacherId);
      emit(TeacherAvailabilityLoaded(slots: slots));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onAvailabilityUpdateRequested(
    TeacherAvailabilityUpdateRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final slots = await teacherRepository.setAvailability(event.slots);
      emit(TeacherAvailabilityLoaded(slots: slots));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  Future<void> _onEarningsRequested(
    TeacherEarningsRequested event,
    Emitter<TeacherState> emit,
  ) async {
    emit(TeacherLoading());
    try {
      final earnings = await teacherRepository.getEarnings();
      emit(TeacherEarningsLoaded(earnings: earnings));
    } catch (e) {
      emit(TeacherError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      // Try to extract DioException message
      if (msg.contains('DioException')) {
        final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(msg);
        if (match != null) return match.group(1)!;
        final msgMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(msg);
        if (msgMatch != null) return msgMatch.group(1)!;
      }
      return msg.replaceFirst('Exception: ', '');
    }
    return 'Une erreur est survenue';
  }
}
