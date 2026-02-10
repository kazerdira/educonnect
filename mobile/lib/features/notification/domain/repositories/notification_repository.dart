import 'package:educonnect/features/notification/domain/entities/notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> listNotifications();

  Future<void> markAsRead(String id);

  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences({
    bool? emailEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? sessionReminder,
    bool? newReview,
    bool? paymentUpdate,
    bool? systemUpdate,
  });
}
