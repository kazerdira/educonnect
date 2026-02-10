import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/session/domain/entities/session.dart';
import 'package:educonnect/features/session/presentation/bloc/session_bloc.dart';

class SessionDetailPage extends StatefulWidget {
  final String sessionId;
  const SessionDetailPage({super.key, required this.sessionId});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<SessionBloc>()
        .add(SessionDetailRequested(sessionId: widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Détails de la session')),
      body: BlocConsumer<SessionBloc, SessionState>(
        listener: (context, state) {
          if (state is SessionCancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session annulée')),
            );
            Navigator.pop(context);
          }
          if (state is SessionJoined) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Connecté au salon : ${state.result.roomId}')),
            );
          }
          if (state is SessionEnded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session terminée')),
            );
            Navigator.pop(context);
          }
          if (state is SessionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is SessionLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SessionDetailLoaded) {
            return _body(state.session, theme);
          }

          if (state is SessionError) {
            return Center(child: Text(state.message));
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _body(Session session, ThemeData theme) {
    DateTime? startDate;
    DateTime? endDate;
    try {
      startDate = DateTime.parse(session.startTime);
      endDate = DateTime.parse(session.endTime);
    } catch (_) {}

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & status
          Text(
            session.title,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          _statusChip(session.status),
          SizedBox(height: 16.h),

          if (session.description != null &&
              session.description!.isNotEmpty) ...[
            Text(
              session.description!,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 16.h),
          ],

          // Info card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _infoRow(
                    Icons.person_outline,
                    'Enseignant',
                    session.teacherName,
                  ),
                  Divider(height: 24.h),
                  _infoRow(
                    Icons.calendar_today,
                    'Date de début',
                    startDate != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(startDate)
                        : session.startTime,
                  ),
                  Divider(height: 24.h),
                  _infoRow(
                    Icons.calendar_today,
                    'Date de fin',
                    endDate != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(endDate)
                        : session.endTime,
                  ),
                  Divider(height: 24.h),
                  _infoRow(
                    Icons.group,
                    'Type',
                    session.sessionType == 'individual'
                        ? 'Individuelle'
                        : 'Groupe (max ${session.maxStudents})',
                  ),
                  Divider(height: 24.h),
                  _infoRow(
                    Icons.monetization_on,
                    'Prix',
                    '${session.price.toStringAsFixed(0)} DA',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Participants
          if (session.participants.isNotEmpty) ...[
            Text(
              'Participants (${session.participants.length})',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            ...session.participants.map(
              (p) => ListTile(
                leading: CircleAvatar(
                  radius: 18.r,
                  child:
                      Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                ),
                title: Text(p.name),
                trailing: Text(
                  p.attendance,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color:
                        p.attendance == 'present' ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
          ],

          // Actions
          if (session.status == 'scheduled') ...[
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: () => context
                    .read<SessionBloc>()
                    .add(JoinSessionRequested(sessionId: session.id)),
                icon: const Icon(Icons.video_call),
                label: const Text('Rejoindre la session'),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRescheduleDialog(session),
                    child: const Text('Reporter'),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showCancelDialog(session.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
          ],

          if (session.status == 'in_progress') ...[
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: () => context
                    .read<SessionBloc>()
                    .add(JoinSessionRequested(sessionId: session.id)),
                icon: const Icon(Icons.video_call),
                label: const Text('Rejoindre'),
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: OutlinedButton(
                onPressed: () => context
                    .read<SessionBloc>()
                    .add(EndSessionRequested(sessionId: session.id)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Terminer la session'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'scheduled':
        color = Colors.blue;
        label = 'Planifiée';
        break;
      case 'in_progress':
        color = Colors.green;
        label = 'En cours';
        break;
      case 'completed':
        color = Colors.grey;
        label = 'Terminée';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Annulée';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12.sp)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: Colors.grey[600]),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
              Text(value, style: TextStyle(fontSize: 14.sp)),
            ],
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(String sessionId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la session'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Motif d\'annulation (min 5 caractères)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().length < 5) return;
              context.read<SessionBloc>().add(CancelSessionRequested(
                    sessionId: sessionId,
                    reason: reasonCtrl.text.trim(),
                  ));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(Session session) {
    DateTime? newStart;
    DateTime? newEnd;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reporter la session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(newStart == null
                  ? 'Choisir le début'
                  : DateFormat('dd/MM/yyyy HH:mm').format(newStart!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: ctx,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null) return;
                final time = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                newStart = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute);
                (ctx as Element).markNeedsBuild();
              },
            ),
            ListTile(
              title: Text(newEnd == null
                  ? 'Choisir la fin'
                  : DateFormat('dd/MM/yyyy HH:mm').format(newEnd!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: ctx,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null) return;
                final time = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                newEnd = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute);
                (ctx as Element).markNeedsBuild();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newStart == null || newEnd == null) return;
              context.read<SessionBloc>().add(RescheduleSessionRequested(
                    sessionId: session.id,
                    startTime: newStart!.toUtc().toIso8601String(),
                    endTime: newEnd!.toUtc().toIso8601String(),
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Reporter'),
          ),
        ],
      ),
    );
  }
}
