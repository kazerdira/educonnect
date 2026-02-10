import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String createdAt;
  final String updatedAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class NotificationPreferences extends Equatable {
  final String userId;
  final bool emailEnabled;
  final bool pushEnabled;
  final bool smsEnabled;
  final bool sessionReminder;
  final bool newReview;
  final bool paymentUpdate;
  final bool systemUpdate;

  const NotificationPreferences({
    required this.userId,
    required this.emailEnabled,
    required this.pushEnabled,
    required this.smsEnabled,
    required this.sessionReminder,
    required this.newReview,
    required this.paymentUpdate,
    required this.systemUpdate,
  });

  @override
  List<Object?> get props => [userId];
}
