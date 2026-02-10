import 'package:educonnect/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:educonnect/features/notification/domain/entities/notification.dart';
import 'package:educonnect/features/notification/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AppNotification>> listNotifications() =>
      remoteDataSource.listNotifications();

  @override
  Future<void> markAsRead(String id) => remoteDataSource.markAsRead(id);

  @override
  Future<NotificationPreferences> getPreferences() =>
      remoteDataSource.getPreferences();

  @override
  Future<NotificationPreferences> updatePreferences({
    bool? emailEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? sessionReminder,
    bool? newReview,
    bool? paymentUpdate,
    bool? systemUpdate,
  }) =>
      remoteDataSource.updatePreferences(
        emailEnabled: emailEnabled,
        pushEnabled: pushEnabled,
        smsEnabled: smsEnabled,
        sessionReminder: sessionReminder,
        newReview: newReview,
        paymentUpdate: paymentUpdate,
        systemUpdate: systemUpdate,
      );
}
