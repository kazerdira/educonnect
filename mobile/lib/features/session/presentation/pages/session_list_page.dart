import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/session/domain/entities/session.dart';
import 'package:educonnect/features/session/presentation/bloc/session_bloc.dart';

class SessionListPage extends StatefulWidget {
  final bool showCreateButton;
  const SessionListPage({super.key, this.showCreateButton = true});

  @override
  State<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends State<SessionListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statuses = [
    null,
    'scheduled',
    'in_progress',
    'completed',
    'cancelled'
  ];
  static const _statusLabels = [
    'Toutes',
    'Planifiées',
    'En cours',
    'Terminées',
    'Annulées'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSessions();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadSessions();
  }

  void _loadSessions() {
    context.read<SessionBloc>().add(
          SessionsListRequested(status: _statuses[_tabController.index]),
        );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Sessions'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      floatingActionButton: widget.showCreateButton
          ? FloatingActionButton(
              heroTag: 'session_list_fab',
              onPressed: () => context.push('/sessions/create'),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _loadSessions(),
        child: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, state) {
            if (state is SessionLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SessionError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                    SizedBox(height: 8.h),
                    Text(state.message),
                    SizedBox(height: 8.h),
                    ElevatedButton(
                      onPressed: _loadSessions,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            if (state is SessionsLoaded) {
              if (state.sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_camera_front_outlined,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text(
                        'Aucune session',
                        style:
                            TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.sessions.length,
                itemBuilder: (context, index) =>
                    _SessionCard(session: state.sessions[index]),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  const _SessionCard({required this.session});

  Color _statusColor() {
    switch (session.status) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel() {
    switch (session.status) {
      case 'scheduled':
        return 'Planifiée';
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return session.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime? startDate;
    try {
      startDate = DateTime.parse(session.startTime);
    } catch (_) {}

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => context.push('/sessions/${session.id}'),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: _statusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    session.teacherName,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    startDate != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(startDate)
                        : session.startTime,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Text(
                    session.sessionType == 'individual'
                        ? 'Individuelle'
                        : 'Groupe',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                  const Spacer(),
                  Text(
                    '${session.price.toStringAsFixed(0)} DA',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
