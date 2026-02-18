import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/notification/domain/entities/notification.dart';
import 'package:educonnect/features/notification/domain/repositories/notification_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class NotificationsListRequested extends NotificationEvent {}

class MarkNotificationReadRequested extends NotificationEvent {
  final String notificationId;
  const MarkNotificationReadRequested({required this.notificationId});
  @override
  List<Object?> get props => [notificationId];
}

class PreferencesLoadRequested extends NotificationEvent {}

class PreferencesUpdateRequested extends NotificationEvent {
  final bool? emailEnabled;
  final bool? pushEnabled;
  final bool? smsEnabled;
  final bool? sessionReminder;
  final bool? newReview;
  final bool? paymentUpdate;
  final bool? systemUpdate;

  const PreferencesUpdateRequested({
    this.emailEnabled,
    this.pushEnabled,
    this.smsEnabled,
    this.sessionReminder,
    this.newReview,
    this.paymentUpdate,
    this.systemUpdate,
  });

  @override
  List<Object?> get props => [
        emailEnabled,
        pushEnabled,
        smsEnabled,
        sessionReminder,
        newReview,
        paymentUpdate,
        systemUpdate,
      ];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationsLoaded extends NotificationState {
  final List<AppNotification> notifications;
  const NotificationsLoaded({required this.notifications});
  @override
  List<Object?> get props => [notifications];
}

class NotificationMarkedRead extends NotificationState {
  final String notificationId;
  const NotificationMarkedRead({required this.notificationId});
  @override
  List<Object?> get props => [notificationId];
}

class PreferencesLoaded extends NotificationState {
  final NotificationPreferences preferences;
  const PreferencesLoaded({required this.preferences});
  @override
  List<Object?> get props => [preferences];
}

class PreferencesUpdated extends NotificationState {
  final NotificationPreferences preferences;
  const PreferencesUpdated({required this.preferences});
  @override
  List<Object?> get props => [preferences];
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository notificationRepository;

  NotificationBloc({required this.notificationRepository})
      : super(NotificationInitial()) {
    on<NotificationsListRequested>(_onList);
    on<MarkNotificationReadRequested>(_onMarkRead);
    on<PreferencesLoadRequested>(_onLoadPreferences);
    on<PreferencesUpdateRequested>(_onUpdatePreferences);
  }

  Future<void> _onList(
    NotificationsListRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final notifications = await notificationRepository.listNotifications();
      emit(NotificationsLoaded(notifications: notifications));
    } catch (e) {
      emit(NotificationError(message: _extractError(e)));
    }
  }

  Future<void> _onMarkRead(
    MarkNotificationReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await notificationRepository.markAsRead(event.notificationId);
      emit(NotificationMarkedRead(notificationId: event.notificationId));
      // Reload the list after marking as read
      final notifications = await notificationRepository.listNotifications();
      emit(NotificationsLoaded(notifications: notifications));
    } catch (e) {
      emit(NotificationError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadPreferences(
    PreferencesLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final prefs = await notificationRepository.getPreferences();
      emit(PreferencesLoaded(preferences: prefs));
    } catch (e) {
      emit(NotificationError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdatePreferences(
    PreferencesUpdateRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final prefs = await notificationRepository.updatePreferences(
        emailEnabled: event.emailEnabled,
        pushEnabled: event.pushEnabled,
        smsEnabled: event.smsEnabled,
        sessionReminder: event.sessionReminder,
        newReview: event.newReview,
        paymentUpdate: event.paymentUpdate,
        systemUpdate: event.systemUpdate,
      );
      emit(PreferencesUpdated(preferences: prefs));
    } catch (e) {
      emit(NotificationError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
