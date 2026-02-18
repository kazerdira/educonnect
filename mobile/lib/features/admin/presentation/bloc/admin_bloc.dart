import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/domain/repositories/admin_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class AdminEvent extends Equatable {
  const AdminEvent();
  @override
  List<Object?> get props => [];
}

class AdminUsersRequested extends AdminEvent {}

class AdminUserDetailRequested extends AdminEvent {
  final String userId;
  const AdminUserDetailRequested({required this.userId});
  @override
  List<Object?> get props => [userId];
}

class AdminSuspendUserRequested extends AdminEvent {
  final String userId;
  final String reason;
  final String? duration;
  const AdminSuspendUserRequested({
    required this.userId,
    required this.reason,
    this.duration,
  });
  @override
  List<Object?> get props => [userId, reason];
}

class AdminUnsuspendUserRequested extends AdminEvent {
  final String userId;
  const AdminUnsuspendUserRequested({required this.userId});
  @override
  List<Object?> get props => [userId];
}

class AdminVerificationsRequested extends AdminEvent {}

class AdminApproveVerificationRequested extends AdminEvent {
  final String verificationId;
  const AdminApproveVerificationRequested({required this.verificationId});
  @override
  List<Object?> get props => [verificationId];
}

class AdminRejectVerificationRequested extends AdminEvent {
  final String verificationId;
  final String? note;
  const AdminRejectVerificationRequested({
    required this.verificationId,
    this.note,
  });
  @override
  List<Object?> get props => [verificationId];
}

class AdminDisputesRequested extends AdminEvent {}

class AdminResolveDisputeRequested extends AdminEvent {
  final String disputeId;
  final String resolution;
  const AdminResolveDisputeRequested({
    required this.disputeId,
    required this.resolution,
  });
  @override
  List<Object?> get props => [disputeId, resolution];
}

class AdminAnalyticsRequested extends AdminEvent {}

class AdminRevenueRequested extends AdminEvent {}

class AdminUpdateSubjectsRequested extends AdminEvent {
  final List<Subject> subjects;
  const AdminUpdateSubjectsRequested({required this.subjects});
  @override
  List<Object?> get props => [subjects];
}

class AdminUpdateLevelsRequested extends AdminEvent {
  final List<Level> levels;
  const AdminUpdateLevelsRequested({required this.levels});
  @override
  List<Object?> get props => [levels];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminUsersLoaded extends AdminState {
  final List<AdminUser> users;
  const AdminUsersLoaded({required this.users});
  @override
  List<Object?> get props => [users];
}

class AdminUserDetailLoaded extends AdminState {
  final AdminUser user;
  const AdminUserDetailLoaded({required this.user});
  @override
  List<Object?> get props => [user];
}

class AdminUserSuspended extends AdminState {}

class AdminUserUnsuspended extends AdminState {}

class AdminVerificationsLoaded extends AdminState {
  final List<Verification> verifications;
  const AdminVerificationsLoaded({required this.verifications});
  @override
  List<Object?> get props => [verifications];
}

class AdminVerificationApproved extends AdminState {}

class AdminVerificationRejected extends AdminState {}

class AdminDisputesLoaded extends AdminState {
  final List<Dispute> disputes;
  const AdminDisputesLoaded({required this.disputes});
  @override
  List<Object?> get props => [disputes];
}

class AdminDisputeResolved extends AdminState {}

class AdminAnalyticsLoaded extends AdminState {
  final AnalyticsOverview overview;
  const AdminAnalyticsLoaded({required this.overview});
  @override
  List<Object?> get props => [overview];
}

class AdminRevenueLoaded extends AdminState {
  final RevenueAnalytics revenue;
  const AdminRevenueLoaded({required this.revenue});
  @override
  List<Object?> get props => [revenue];
}

class AdminSubjectsUpdated extends AdminState {
  final List<Subject> subjects;
  const AdminSubjectsUpdated({required this.subjects});
  @override
  List<Object?> get props => [subjects];
}

class AdminLevelsUpdated extends AdminState {
  final List<Level> levels;
  const AdminLevelsUpdated({required this.levels});
  @override
  List<Object?> get props => [levels];
}

class AdminError extends AdminState {
  final String message;
  const AdminError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminRepository adminRepository;

  AdminBloc({required this.adminRepository}) : super(AdminInitial()) {
    on<AdminUsersRequested>(_onListUsers);
    on<AdminUserDetailRequested>(_onGetUser);
    on<AdminSuspendUserRequested>(_onSuspendUser);
    on<AdminUnsuspendUserRequested>(_onUnsuspendUser);
    on<AdminVerificationsRequested>(_onListVerifications);
    on<AdminApproveVerificationRequested>(_onApproveVerification);
    on<AdminRejectVerificationRequested>(_onRejectVerification);
    on<AdminDisputesRequested>(_onListDisputes);
    on<AdminResolveDisputeRequested>(_onResolveDispute);
    on<AdminAnalyticsRequested>(_onGetAnalytics);
    on<AdminRevenueRequested>(_onGetRevenue);
    on<AdminUpdateSubjectsRequested>(_onUpdateSubjects);
    on<AdminUpdateLevelsRequested>(_onUpdateLevels);
  }

  Future<void> _onListUsers(
    AdminUsersRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final users = await adminRepository.listUsers();
      emit(AdminUsersLoaded(users: users));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onGetUser(
    AdminUserDetailRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final user = await adminRepository.getUser(event.userId);
      emit(AdminUserDetailLoaded(user: user));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onSuspendUser(
    AdminSuspendUserRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      await adminRepository.suspendUser(
        event.userId,
        reason: event.reason,
        duration: event.duration,
      );
      emit(AdminUserSuspended());
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onUnsuspendUser(
    AdminUnsuspendUserRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      await adminRepository.unsuspendUser(event.userId);
      emit(AdminUserUnsuspended());
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onListVerifications(
    AdminVerificationsRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final verifications = await adminRepository.listVerifications();
      emit(AdminVerificationsLoaded(verifications: verifications));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onApproveVerification(
    AdminApproveVerificationRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      await adminRepository.approveVerification(event.verificationId);
      emit(AdminVerificationApproved());
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onRejectVerification(
    AdminRejectVerificationRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      await adminRepository.rejectVerification(
        event.verificationId,
        note: event.note,
      );
      emit(AdminVerificationRejected());
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onListDisputes(
    AdminDisputesRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final disputes = await adminRepository.listDisputes();
      emit(AdminDisputesLoaded(disputes: disputes));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onResolveDispute(
    AdminResolveDisputeRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      await adminRepository.resolveDispute(
        event.disputeId,
        resolution: event.resolution,
      );
      emit(AdminDisputeResolved());
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onGetAnalytics(
    AdminAnalyticsRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final overview = await adminRepository.getAnalyticsOverview();
      emit(AdminAnalyticsLoaded(overview: overview));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onGetRevenue(
    AdminRevenueRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final revenue = await adminRepository.getRevenueAnalytics();
      emit(AdminRevenueLoaded(revenue: revenue));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdateSubjects(
    AdminUpdateSubjectsRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final subjects = await adminRepository.updateSubjects(event.subjects);
      emit(AdminSubjectsUpdated(subjects: subjects));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdateLevels(
    AdminUpdateLevelsRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final levels = await adminRepository.updateLevels(event.levels);
      emit(AdminLevelsUpdated(levels: levels));
    } catch (e) {
      emit(AdminError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
