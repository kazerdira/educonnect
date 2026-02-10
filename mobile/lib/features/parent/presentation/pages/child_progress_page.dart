import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';

class ChildProgressPage extends StatefulWidget {
  final String childId;

  const ChildProgressPage({super.key, required this.childId});

  @override
  State<ChildProgressPage> createState() => _ChildProgressPageState();
}

class _ChildProgressPageState extends State<ChildProgressPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<ParentBloc>()
        .add(ChildProgressRequested(childId: widget.childId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Progression')),
      body: BlocBuilder<ParentBloc, ParentState>(
        builder: (context, state) {
          if (state is ParentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ParentError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48.sp, color: Colors.red[300]),
                  SizedBox(height: 12.h),
                  Text(state.message, textAlign: TextAlign.center),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<ParentBloc>()
                        .add(ChildProgressRequested(childId: widget.childId)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is ChildProgressLoaded) {
            final progress = state.progress;

            if (progress.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart, size: 64.sp, color: Colors.grey[400]),
                    SizedBox(height: 12.h),
                    Text(
                      'Aucune donnée de progression',
                      style:
                          TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<ParentBloc>()
                    .add(ChildProgressRequested(childId: widget.childId));
              },
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  // ── Summary cards ─────────────────────────────
                  if (progress['total_sessions'] != null ||
                      progress['average_score'] != null)
                    _summarySection(theme, progress),

                  SizedBox(height: 16.h),

                  // ── Recent sessions ───────────────────────────
                  if (progress['recent_sessions'] is List &&
                      (progress['recent_sessions'] as List).isNotEmpty) ...[
                    Text('Sessions récentes',
                        style: theme.textTheme.titleMedium),
                    SizedBox(height: 8.h),
                    ...(progress['recent_sessions'] as List).map(
                      (s) => Card(
                        margin: EdgeInsets.only(bottom: 8.h),
                        child: ListTile(
                          leading: Icon(Icons.event_note,
                              color: theme.colorScheme.primary),
                          title: Text(s['subject']?.toString() ?? 'Session'),
                          subtitle: Text(s['date']?.toString() ?? ''),
                          trailing: s['score'] != null
                              ? Chip(label: Text('${s['score']}'))
                              : null,
                        ),
                      ),
                    ),
                  ],

                  // ── Fallback: display all keys ────────────────
                  if (progress['recent_sessions'] == null &&
                      progress['total_sessions'] == null)
                    ...progress.entries.map(
                      (e) => Card(
                        margin: EdgeInsets.only(bottom: 8.h),
                        child: ListTile(
                          title: Text(e.key),
                          subtitle: Text(e.value?.toString() ?? '—'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _summarySection(ThemeData theme, Map<String, dynamic> progress) {
    return Row(
      children: [
        if (progress['total_sessions'] != null)
          _statCard(
            theme,
            icon: Icons.event,
            label: 'Sessions',
            value: '${progress['total_sessions']}',
            color: Colors.blue,
          ),
        if (progress['average_score'] != null)
          _statCard(
            theme,
            icon: Icons.star,
            label: 'Moyenne',
            value: '${progress['average_score']}',
            color: Colors.orange,
          ),
        if (progress['completed_homeworks'] != null)
          _statCard(
            theme,
            icon: Icons.assignment_turned_in,
            label: 'Devoirs',
            value: '${progress['completed_homeworks']}',
            color: Colors.green,
          ),
      ],
    );
  }

  Widget _statCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28.sp),
              SizedBox(height: 4.h),
              Text(value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 2.h),
              Text(label,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
