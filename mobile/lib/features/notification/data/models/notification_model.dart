import 'package:educonnect/features/notification/domain/entities/notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.title,
    required super.body,
    required super.isRead,
    super.data,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'is_read': isRead,
        if (data != null) 'data': data,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.userId,
    required super.emailEnabled,
    required super.pushEnabled,
    required super.smsEnabled,
    required super.sessionReminder,
    required super.newReview,
    required super.paymentUpdate,
    required super.systemUpdate,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      userId: json['user_id'] as String? ?? '',
      emailEnabled: json['email_enabled'] as bool? ?? false,
      pushEnabled: json['push_enabled'] as bool? ?? false,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
      sessionReminder: json['session_reminder'] as bool? ?? false,
      newReview: json['new_review'] as bool? ?? false,
      paymentUpdate: json['payment_update'] as bool? ?? false,
      systemUpdate: json['system_update'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email_enabled': emailEnabled,
        'push_enabled': pushEnabled,
        'sms_enabled': smsEnabled,
        'session_reminder': sessionReminder,
        'new_review': newReview,
        'payment_update': paymentUpdate,
        'system_update': systemUpdate,
      };
}
