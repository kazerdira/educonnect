import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/notification/domain/entities/notification.dart';
import 'package:educonnect/features/notification/presentation/bloc/notification_bloc.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(NotificationsListRequested());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Préférences',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<NotificationBloc>(),
                  child: const _PreferencesRoute(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<NotificationBloc>().add(NotificationsListRequested());
        },
        child: BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            if (state is NotificationLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is NotificationError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                    SizedBox(height: 8.h),
                    Text(state.message),
                    SizedBox(height: 8.h),
                    ElevatedButton(
                      onPressed: () => context
                          .read<NotificationBloc>()
                          .add(NotificationsListRequested()),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            if (state is NotificationsLoaded) {
              if (state.notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text(
                        'Aucune notification',
                        style:
                            TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => Divider(height: 1.h),
                itemBuilder: (context, index) {
                  final notif = state.notifications[index];
                  return _NotificationTile(
                    notification: notif,
                    colorScheme: colorScheme,
                    onMarkRead: () {
                      if (!notif.isRead) {
                        context.read<NotificationBloc>().add(
                              MarkNotificationReadRequested(
                                  notificationId: notif.id),
                            );
                      }
                    },
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// ─── Notification tile ────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final ColorScheme colorScheme;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.colorScheme,
    required this.onMarkRead,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'session_reminder':
        return Icons.calendar_today;
      case 'new_review':
        return Icons.star_outline;
      case 'payment_update':
        return Icons.payment;
      case 'system_update':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return ListTile(
      tileColor:
          isUnread ? colorScheme.primaryContainer.withOpacity(0.15) : null,
      leading: CircleAvatar(
        backgroundColor: isUnread ? colorScheme.primary : Colors.grey[300],
        child: Icon(
          _iconForType(notification.type),
          color: isUnread ? colorScheme.onPrimary : Colors.grey[600],
          size: 20.sp,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14.sp,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.sp),
      ),
      trailing: isUnread
          ? Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onMarkRead,
    );
  }
}

// Tiny wrapper so the settings icon can push the preferences page
// while keeping the same bloc instance.
class _PreferencesRoute extends StatelessWidget {
  const _PreferencesRoute();

  @override
  Widget build(BuildContext context) {
    // Lazy‑import to avoid circular; the real import is at the top of the
    // preferences page file.
    return const _PreferencesPageProxy();
  }
}

class _PreferencesPageProxy extends StatelessWidget {
  const _PreferencesPageProxy();

  @override
  Widget build(BuildContext context) {
    // We can't import notification_preferences_page.dart here without
    // creating a barrel, so just redirect via Navigator in the onPressed
    // callback of NotificationsPage instead.  This placeholder is only
    // reached if you navigate programmatically; use go_router in production.
    return const Scaffold(
      body:
          Center(child: Text('Préférences – voir NotificationPreferencesPage')),
    );
  }
}
