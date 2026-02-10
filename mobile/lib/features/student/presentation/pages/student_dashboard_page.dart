import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/student/presentation/bloc/student_bloc.dart';
import 'package:educonnect/features/student/domain/entities/student.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<StudentBloc>().add(StudentDashboardRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon tableau de bord'),
      ),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          if (state is StudentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is StudentError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                  SizedBox(height: 12.h),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<StudentBloc>()
                        .add(StudentDashboardRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is StudentDashboardLoaded) {
            return _buildDashboard(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, StudentDashboardLoaded state) {
    final theme = Theme.of(context);
    final dashboard = state.dashboard;
    final sessions = state.recentSessions;
    final enrollments = state.enrollments;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StudentBloc>().add(StudentDashboardRequested());
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // ── Welcome ──
          Text(
            'Bonjour, ${dashboard.firstName} !',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          if (dashboard.levelName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                dashboard.levelName,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
          SizedBox(height: 16.h),

          // ── Stats Cards ──
          Row(
            children: [
              _statCard(
                icon: Icons.video_camera_front_outlined,
                label: 'Total Sessions',
                value: '${dashboard.totalSessions}',
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 8.w),
              _statCard(
                icon: Icons.menu_book_outlined,
                label: 'Total Cours',
                value: '${dashboard.totalCourses}',
                color: theme.colorScheme.secondary,
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // ── Recent Sessions ──
          Text(
            'Sessions récentes',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (sessions.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Center(
                  child: Text(
                    'Aucune session récente',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            )
          else
            ...sessions.map((s) => _sessionCard(s, theme)),

          SizedBox(height: 20.h),

          // ── Enrollments ──
          Text(
            'Mes inscriptions',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (enrollments.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Center(
                  child: Text(
                    'Aucune inscription',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            )
          else
            ...enrollments.map((e) => _enrollmentCard(e, theme)),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // ── Stat Card ──

  Widget _statCard({
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
              Icon(icon, size: 28.sp, color: color),
              SizedBox(height: 8.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Session Card ──

  Widget _sessionCard(StudentSessionBrief session, ThemeData theme) {
    final dateStr = DateFormat('dd MMM yyyy – HH:mm').format(session.startTime);
    final statusColor = _sessionStatusColor(session.status);

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            session.type == 'live'
                ? Icons.videocam_outlined
                : Icons.play_lesson_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              session.teacherName,
              style: TextStyle(fontSize: 12.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            session.status,
            style: TextStyle(
              fontSize: 11.sp,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Color _sessionStatusColor(String status) {
    switch (status) {
      case 'live':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  // ── Enrollment Card ──

  Widget _enrollmentCard(StudentEnrollment enrollment, ThemeData theme) {
    final progressPct = (enrollment.progress * 100).toStringAsFixed(0);
    final dateStr = DateFormat('dd MMM yyyy').format(enrollment.enrolledAt);

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    enrollment.courseName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _enrollmentStatusColor(enrollment.status)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    enrollment.status,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: _enrollmentStatusColor(enrollment.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Inscrit le $dateStr',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: enrollment.progress,
                      minHeight: 6.h,
                      backgroundColor: Colors.grey[200],
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '$progressPct%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _enrollmentStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'dropped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
