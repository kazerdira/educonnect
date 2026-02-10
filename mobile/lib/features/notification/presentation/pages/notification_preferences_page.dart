import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/notification/domain/entities/notification.dart';
import 'package:educonnect/features/notification/presentation/bloc/notification_bloc.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  // Local toggle state – initialised from loaded preferences.
  bool _emailEnabled = false;
  bool _pushEnabled = false;
  bool _smsEnabled = false;
  bool _sessionReminder = false;
  bool _newReview = false;
  bool _paymentUpdate = false;
  bool _systemUpdate = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(PreferencesLoadRequested());
  }

  void _applyFromPreferences(NotificationPreferences prefs) {
    setState(() {
      _emailEnabled = prefs.emailEnabled;
      _pushEnabled = prefs.pushEnabled;
      _smsEnabled = prefs.smsEnabled;
      _sessionReminder = prefs.sessionReminder;
      _newReview = prefs.newReview;
      _paymentUpdate = prefs.paymentUpdate;
      _systemUpdate = prefs.systemUpdate;
      _initialised = true;
    });
  }

  void _onToggle(String key, bool value) {
    setState(() {
      switch (key) {
        case 'email_enabled':
          _emailEnabled = value;
        case 'push_enabled':
          _pushEnabled = value;
        case 'sms_enabled':
          _smsEnabled = value;
        case 'session_reminder':
          _sessionReminder = value;
        case 'new_review':
          _newReview = value;
        case 'payment_update':
          _paymentUpdate = value;
        case 'system_update':
          _systemUpdate = value;
      }
    });

    context.read<NotificationBloc>().add(
          PreferencesUpdateRequested(
            emailEnabled: key == 'email_enabled' ? value : null,
            pushEnabled: key == 'push_enabled' ? value : null,
            smsEnabled: key == 'sms_enabled' ? value : null,
            sessionReminder: key == 'session_reminder' ? value : null,
            newReview: key == 'new_review' ? value : null,
            paymentUpdate: key == 'payment_update' ? value : null,
            systemUpdate: key == 'system_update' ? value : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences de notification')),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          if (state is PreferencesLoaded && !_initialised) {
            _applyFromPreferences(state.preferences);
          }
          if (state is PreferencesUpdated) {
            _applyFromPreferences(state.preferences);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Préférences mises à jour'),
                  duration: Duration(seconds: 1)),
            );
          }
          if (state is NotificationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is NotificationLoading && !_initialised) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            children: [
              _SectionHeader(title: 'Canaux de notification'),
              _PrefSwitch(
                label: 'Email',
                subtitle: 'Recevoir des notifications par email',
                icon: Icons.email_outlined,
                value: _emailEnabled,
                onChanged: (v) => _onToggle('email_enabled', v),
              ),
              _PrefSwitch(
                label: 'Notifications push',
                subtitle: 'Recevoir des notifications push',
                icon: Icons.phone_android,
                value: _pushEnabled,
                onChanged: (v) => _onToggle('push_enabled', v),
              ),
              _PrefSwitch(
                label: 'SMS',
                subtitle: 'Recevoir des notifications par SMS',
                icon: Icons.sms_outlined,
                value: _smsEnabled,
                onChanged: (v) => _onToggle('sms_enabled', v),
              ),
              SizedBox(height: 16.h),
              _SectionHeader(title: 'Types de notification'),
              _PrefSwitch(
                label: 'Rappels de session',
                subtitle: 'Être notifié avant les sessions planifiées',
                icon: Icons.calendar_today,
                value: _sessionReminder,
                onChanged: (v) => _onToggle('session_reminder', v),
              ),
              _PrefSwitch(
                label: 'Nouveaux avis',
                subtitle: 'Être notifié des nouveaux avis reçus',
                icon: Icons.star_outline,
                value: _newReview,
                onChanged: (v) => _onToggle('new_review', v),
              ),
              _PrefSwitch(
                label: 'Mises à jour de paiement',
                subtitle: 'Être notifié des mises à jour de paiement',
                icon: Icons.payment,
                value: _paymentUpdate,
                onChanged: (v) => _onToggle('payment_update', v),
              ),
              _PrefSwitch(
                label: 'Mises à jour système',
                subtitle: 'Recevoir les annonces et mises à jour système',
                icon: Icons.info_outline,
                value: _systemUpdate,
                onChanged: (v) => _onToggle('system_update', v),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefSwitch({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 24.sp),
      title: Text(label, style: TextStyle(fontSize: 14.sp)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12.sp)),
      value: value,
      onChanged: onChanged,
    );
  }
}
