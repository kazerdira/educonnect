import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/session/data/models/session_series_model.dart';
import 'package:educonnect/features/session/domain/entities/session_series.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';

class SeriesDetailPage extends StatelessWidget {
  final String seriesId;
  const SeriesDetailPage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<SeriesBloc>()..add(SeriesDetailRequested(seriesId: seriesId)),
      child: _SeriesDetailView(seriesId: seriesId),
    );
  }
}

class _SeriesDetailView extends StatelessWidget {
  final String seriesId;
  const _SeriesDetailView({required this.seriesId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SeriesBloc, SeriesState>(
      listener: (context, state) {
        if (state is SeriesFinalized) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Série finalisée avec succès !',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is StudentsInvited) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${state.enrollments.length} élève(s) invité(s)'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh series detail
          context
              .read<SeriesBloc>()
              .add(SeriesDetailRequested(seriesId: seriesId));
        } else if (state is RequestAccepted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande acceptée!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh series detail
          context
              .read<SeriesBloc>()
              .add(SeriesDetailRequested(seriesId: seriesId));
        } else if (state is RequestDeclined) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande refusée'),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh series detail
          context
              .read<SeriesBloc>()
              .add(SeriesDetailRequested(seriesId: seriesId));
        } else if (state is SessionsAddedToSeries) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${state.series.sessions.length} session(s) ajoutée(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is SeriesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is SeriesLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détails de la série')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is SeriesError && state is! SeriesDetailLoaded) {
          return Scaffold(
            appBar: AppBar(title: const Text('Erreur')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                  SizedBox(height: 8.h),
                  Text(state.message),
                  SizedBox(height: 8.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<SeriesBloc>()
                        .add(SeriesDetailRequested(seriesId: seriesId)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        SessionSeries? series;
        if (state is SeriesDetailLoaded) {
          series = state.series;
        } else if (state is SessionsAddedToSeries) {
          series = state.series;
        } else if (state is SeriesFinalized) {
          series = state.series;
        }

        if (series == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détails de la série')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return _SeriesDetailContent(series: series);
      },
    );
  }
}

class _SeriesDetailContent extends StatelessWidget {
  final SessionSeries series;
  const _SeriesDetailContent({required this.series});

  bool _isOwner(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id == series.teacherId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = _isOwner(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          if (isOwner && !series.isFinalized)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Navigate to edit page
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context
              .read<SeriesBloc>()
              .add(SeriesDetailRequested(seriesId: series.id));
        },
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Status & Type card
            _InfoCard(series: series),
            SizedBox(height: 16.h),

            // Sessions section
            _SectionHeader(
              title: 'Sessions (${series.sessions.length})',
              icon: Icons.event,
              trailing: isOwner && !series.isFinalized
                  ? TextButton.icon(
                      onPressed: () =>
                          _showAddSessionsDialog(context, series.id),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    )
                  : null,
            ),
            SizedBox(height: 8.h),
            if (series.sessions.isEmpty)
              _EmptySection(
                icon: Icons.calendar_month,
                message: 'Aucune session planifiée',
                action: isOwner && !series.isFinalized
                    ? TextButton(
                        onPressed: () =>
                            _showAddSessionsDialog(context, series.id),
                        child: const Text('Ajouter des sessions'),
                      )
                    : null,
              )
            else
              ...series.sessions.map((s) => _SessionTile(session: s)),

            // ── Teacher-only sections ────────────────────
            if (isOwner) ...[
              SizedBox(height: 24.h),

              // Enrollments section
              _SectionHeader(
                title: 'Élèves (${series.enrolledCount}/${series.maxStudents})',
                icon: Icons.people,
                trailing: !series.isFinalized
                    ? TextButton.icon(
                        onPressed: () => _showInviteDialog(context, series.id),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Inviter'),
                      )
                    : null,
              ),
              SizedBox(height: 8.h),
              if (series.enrollments.isEmpty)
                _EmptySection(
                  icon: Icons.people_outline,
                  message: 'Aucun élève inscrit',
                  action: !series.isFinalized
                      ? TextButton(
                          onPressed: () => _showInviteDialog(context, series.id),
                          child: const Text('Inviter des élèves'),
                        )
                      : null,
                )
              else
                ...series.enrollments.map((e) => _EnrollmentTile(
                      enrollment: e,
                      seriesId: series.id,
                    )),
              SizedBox(height: 24.h),

              // Star cost section
              _SectionHeader(
                title: 'Coût en étoiles',
                icon: Icons.star,
              ),
              SizedBox(height: 8.h),
              _StarCostCard(series: series),
              SizedBox(height: 24.h),

              // Actions
              if (!series.isFinalized && series.canFinalize)
                FilledButton.icon(
                  onPressed: () => _showFinalizeDialog(context, series),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Finaliser la série'),
                ),
            ],
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  void _showAddSessionsDialog(BuildContext context, String seriesId) {
    _showFloatingBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: context.read<SeriesBloc>(),
        child: _AddSessionsSheet(seriesId: seriesId),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, String seriesId) {
    _showFloatingBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: context.read<SeriesBloc>(),
        child: _InviteStudentsSheet(seriesId: seriesId),
      ),
    );
  }

  /// Shows a floating bottom sheet with iPhone-like style
  void _showFloatingBottomSheet({
    required BuildContext context,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            child,
            SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  void _showFinalizeDialog(BuildContext context, SessionSeries series) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finaliser la série'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Une fois finalisée, vous ne pourrez plus modifier les sessions ou les inscriptions.',
            ),
            SizedBox(height: 16.h),
            Text(
              'Coût étoile par élève: ${series.starCost.toStringAsFixed(0)} DZD',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<SeriesBloc>()
                  .add(FinalizeSeriesRequested(seriesId: series.id));
            },
            child: const Text('Finaliser'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final SessionSeries series;
  const _InfoCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                _StatusChip(status: series.status),
                const Spacer(),
                Icon(
                  series.isGroup ? Icons.groups : Icons.person,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 4.w),
                Text(
                  series.isGroup ? 'Groupe' : 'Individuel',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Details grid
            Row(
              children: [
                _DetailItem(
                  icon: Icons.schedule,
                  label: 'Durée',
                  value: '${series.durationHours}h',
                ),
                _DetailItem(
                  icon: Icons.event_repeat,
                  label: 'Sessions',
                  value: '${series.totalSessions}',
                ),
                _DetailItem(
                  icon: Icons.payments,
                  label: 'Prix/h',
                  value: '${series.pricePerHour.toStringAsFixed(0)} DA',
                ),
              ],
            ),

            if (series.description != null &&
                series.description!.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Text(
                series.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'draft' => ('Brouillon', Colors.grey),
      'active' => ('Active', Colors.blue),
      'finalized' => ('Finalisée', Colors.green),
      'completed' => ('Terminée', Colors.purple),
      'cancelled' => ('Annulée', Colors.red),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20.sp, color: theme.colorScheme.primary),
          SizedBox(height: 4.h),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20.sp, color: theme.colorScheme.primary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _EmptySection({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40.sp,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (action != null) ...[
            SizedBox(height: 8.h),
            action!,
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionBrief session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE d MMM', 'fr_FR');
    final timeFormat = DateFormat('HH:mm', 'fr_FR');

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${session.sessionNumber}',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(session.title.isNotEmpty
            ? session.title
            : 'Session ${session.sessionNumber}'),
        subtitle: Text(
          '${dateFormat.format(session.startTime)} • ${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}',
        ),
        trailing: _SessionStatusIcon(status: session.status),
      ),
    );
  }
}

class _SessionStatusIcon extends StatelessWidget {
  final String status;
  const _SessionStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'scheduled' => (Icons.event_available, Colors.blue),
      'in_progress' => (Icons.play_circle, Colors.green),
      'completed' => (Icons.check_circle, Colors.grey),
      'cancelled' => (Icons.cancel, Colors.red),
      _ => (Icons.help_outline, Colors.grey),
    };

    return Icon(icon, color: color);
  }
}

class _EnrollmentTile extends StatelessWidget {
  final EnrollmentBrief enrollment;
  final String seriesId;
  const _EnrollmentTile({required this.enrollment, required this.seriesId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = enrollment.status == 'requested';

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Text(
                    enrollment.studentName.isNotEmpty
                        ? enrollment.studentName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enrollment.studentName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        enrollment.isTeacherInitiated
                            ? 'Invité par vous'
                            : 'A demandé à rejoindre',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _EnrollmentStatusChip(status: enrollment.status),
              ],
            ),
            if (isPending && !enrollment.isTeacherInitiated) ...[
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<SeriesBloc>().add(
                            DeclineStudentRequestRequested(
                              seriesId: seriesId,
                              enrollmentId: enrollment.id,
                            ),
                          );
                    },
                    icon: Icon(Icons.close, size: 18.sp),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton.icon(
                    onPressed: () {
                      context.read<SeriesBloc>().add(
                            AcceptStudentRequestRequested(
                              seriesId: seriesId,
                              enrollmentId: enrollment.id,
                            ),
                          );
                    },
                    icon: Icon(Icons.check, size: 18.sp),
                    label: const Text('Accepter'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnrollmentStatusChip extends StatelessWidget {
  final String status;
  const _EnrollmentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'invited' => ('Invité', Colors.blue),
      'requested' => ('Demande', Colors.orange),
      'accepted' => ('Accepté', Colors.green),
      'declined' => ('Refusé', Colors.red),
      'removed' => ('Retiré', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StarCostCard extends StatelessWidget {
  final SessionSeries series;
  const _StarCostCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGroup = series.isGroup;
    final starLabel =
        isGroup ? 'Étoile Groupe (jaune)' : 'Étoile Privé (orange)';
    final starIcon = Icons.star;
    final starColor =
        isGroup ? const Color(0xFFFFD600) : const Color(0xFFFFA726);

    return Card(
      color: starColor.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(starIcon, color: starColor),
                SizedBox(width: 8.w),
                Text(
                  starLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: starColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              '${series.starCost.toStringAsFixed(0)} DZD / élève inscrit',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 4.h),
            Text(
              'Déduit automatiquement à l\'acceptation de l\'inscription.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Add Sessions Sheet =====

class _AddSessionsSheet extends StatefulWidget {
  final String seriesId;
  const _AddSessionsSheet({required this.seriesId});

  @override
  State<_AddSessionsSheet> createState() => _AddSessionsSheetState();
}

class _AddSessionsSheetState extends State<_AddSessionsSheet> {
  final List<DateTime> _selectedDates = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);

  void _addSession() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      setState(() {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _startTime.hour,
          _startTime.minute,
        );
        _selectedDates.add(dateTime);
        _selectedDates.sort();
      });
    }
  }

  void _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (time != null && mounted) {
      setState(() {
        _startTime = time;
        // Update all selected dates with new time
        for (var i = 0; i < _selectedDates.length; i++) {
          final d = _selectedDates[i];
          _selectedDates[i] =
              DateTime(d.year, d.month, d.day, time.hour, time.minute);
        }
      });
    }
  }

  void _submit() {
    if (_selectedDates.isEmpty) return;

    final sessions =
        _selectedDates.map((d) => SessionInput(startTime: d)).toList();

    context.read<SeriesBloc>().add(AddSessionsRequested(
          seriesId: widget.seriesId,
          sessions: sessions,
        ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE d MMM', 'fr_FR');

    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajouter des sessions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          // Start time picker
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Heure de début'),
            subtitle: Text(_startTime.format(context)),
            onTap: _pickStartTime,
          ),
          SizedBox(height: 8.h),

          // Selected dates
          Text(
            'Sessions sélectionnées (${_selectedDates.length}):',
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: 8.h),

          if (_selectedDates.isEmpty)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: const Text('Aucune date sélectionnée'),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _selectedDates.asMap().entries.map((entry) {
                return Chip(
                  label: Text(dateFormat.format(entry.value)),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _selectedDates.removeAt(entry.key));
                  },
                );
              }).toList(),
            ),
          SizedBox(height: 16.h),

          OutlinedButton.icon(
            onPressed: _addSession,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une date'),
          ),
          SizedBox(height: 16.h),

          FilledButton(
            onPressed: _selectedDates.isEmpty ? null : _submit,
            child: Text('Ajouter ${_selectedDates.length} session(s)'),
          ),
        ],
      ),
    );
  }
}

// ===== Invite Students Sheet =====

class _InviteStudentsSheet extends StatefulWidget {
  final String seriesId;
  const _InviteStudentsSheet({required this.seriesId});

  @override
  State<_InviteStudentsSheet> createState() => _InviteStudentsSheetState();
}

class _InviteStudentsSheetState extends State<_InviteStudentsSheet> {
  final _emailController = TextEditingController();
  final List<String> _studentIds = [];
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addStudent() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    // For now, we'll use email as student ID
    // In a real app, you'd search for the student by email
    if (!_studentIds.contains(email)) {
      setState(() {
        _studentIds.add(email);
        _emailController.clear();
      });
    }
  }

  void _submit() {
    if (_studentIds.isEmpty) return;

    // Get bloc reference before popping
    final bloc = context.read<SeriesBloc>();

    // Close the sheet first
    Navigator.pop(context);

    // Then trigger the event
    bloc.add(InviteStudentsRequested(
      seriesId: widget.seriesId,
      studentIds: _studentIds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inviter des élèves',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          // Email input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email ou ID de l\'élève',
                    hintText: 'Entrez l\'email...',
                    prefixIcon: Icon(Icons.email),
                  ),
                  onSubmitted: (_) => _addStudent(),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton.filled(
                onPressed: _addStudent,
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            SizedBox(height: 8.h),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          SizedBox(height: 16.h),

          // Selected students
          Text(
            'Élèves à inviter (${_studentIds.length}):',
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: 8.h),

          if (_studentIds.isEmpty)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: const Text('Aucun élève sélectionné'),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _studentIds.asMap().entries.map((entry) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      entry.value[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  label: Text(entry.value),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _studentIds.removeAt(entry.key));
                  },
                );
              }).toList(),
            ),
          SizedBox(height: 16.h),

          FilledButton(
            onPressed: _studentIds.isEmpty ? null : _submit,
            child: Text('Inviter ${_studentIds.length} élève(s)'),
          ),
        ],
      ),
    );
  }
}
