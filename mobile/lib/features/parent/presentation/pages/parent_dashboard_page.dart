import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<ParentBloc>().add(ParentDashboardRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord parent')),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<ParentBloc>().add(ParentDashboardRequested());
        },
        child: BlocBuilder<ParentBloc, ParentState>(
          builder: (context, state) {
            if (state is ParentLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ParentError) {
              return Center(child: Text(state.message));
            }

            if (state is ParentDashboardLoaded) {
              final d = state.dashboard;
              return ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  // Stats row
                  Row(
                    children: [
                      _statCard(
                        theme,
                        icon: Icons.child_care,
                        label: 'Enfants',
                        value: '${d.totalChildren}',
                        color: Colors.blue,
                      ),
                      SizedBox(width: 12.w),
                      _statCard(
                        theme,
                        icon: Icons.video_camera_front,
                        label: 'Sessions',
                        value: '${d.totalSessions}',
                        color: Colors.green,
                      ),
                      SizedBox(width: 12.w),
                      _statCard(
                        theme,
                        icon: Icons.calendar_today,
                        label: 'À venir',
                        value: '${d.upcomingSessions}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Children section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mes enfants',
                        style: TextStyle(
                            fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/parent/children/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (d.children.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.w),
                        child: Column(
                          children: [
                            Icon(Icons.child_care,
                                size: 48.sp, color: Colors.grey[400]),
                            SizedBox(height: 8.h),
                            Text('Aucun enfant ajouté',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    )
                  else
                    ...d.children.map(
                      (child) => Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              '${child.firstName[0]}${child.lastName[0]}'
                                  .toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('${child.firstName} ${child.lastName}'),
                          subtitle: Text(
                            [child.levelName, child.school]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                              '/parent/children/${child.id}',
                              extra: child),
                        ),
                      ),
                    ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
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
              Text(
                value,
                style: TextStyle(
                    fontSize: 20.sp, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
