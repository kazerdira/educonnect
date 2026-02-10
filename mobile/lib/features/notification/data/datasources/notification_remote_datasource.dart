import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/notification/data/models/notification_model.dart';

class NotificationRemoteDataSource {
  final ApiClient apiClient;

  NotificationRemoteDataSource({required this.apiClient});

  /// GET /notifications
  Future<List<AppNotificationModel>> listNotifications() async {
    final response = await apiClient.get(ApiConstants.notifications);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppNotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /notifications/:id/read
  Future<void> markAsRead(String id) async {
    await apiClient.put(ApiConstants.markNotificationRead(id));
  }

  /// GET /notifications/preferences
  /// NOTE: Backend may not have a GET route for this (only PUT).
  Future<NotificationPreferencesModel> getPreferences() async {
    final response = await apiClient.get(ApiConstants.notificationPreferences);
    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      // Backend returned non-JSON (e.g. 404 HTML page)
      return NotificationPreferencesModel.fromJson({});
    }
    final data = raw['data'] as Map<String, dynamic>?;
    return NotificationPreferencesModel.fromJson(data ?? {});
  }

  /// PUT /notifications/preferences
  Future<NotificationPreferencesModel> updatePreferences({
    bool? emailEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? sessionReminder,
    bool? newReview,
    bool? paymentUpdate,
    bool? systemUpdate,
  }) async {
    final response = await apiClient.put(
      ApiConstants.notificationPreferences,
      data: {
        if (emailEnabled != null) 'email_enabled': emailEnabled,
        if (pushEnabled != null) 'push_enabled': pushEnabled,
        if (smsEnabled != null) 'sms_enabled': smsEnabled,
        if (sessionReminder != null) 'session_reminder': sessionReminder,
        if (newReview != null) 'new_review': newReview,
        if (paymentUpdate != null) 'payment_update': paymentUpdate,
        if (systemUpdate != null) 'system_update': systemUpdate,
      },
    );
    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      return NotificationPreferencesModel.fromJson({});
    }
    final data = raw['data'] as Map<String, dynamic>?;
    return NotificationPreferencesModel.fromJson(data ?? {});
  }
}
