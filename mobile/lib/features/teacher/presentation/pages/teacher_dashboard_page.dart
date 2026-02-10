import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/teacher/domain/entities/teacher_dashboard.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<TeacherBloc>().add(TeacherDashboardRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier le profil',
            onPressed: () => context.push('/teacher/profile/edit'),
          ),
        ],
      ),
      body: BlocBuilder<TeacherBloc, TeacherState>(
        builder: (context, state) {
          if (state is TeacherLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TeacherError) {
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
                        .read<TeacherBloc>()
                        .add(TeacherDashboardRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is TeacherDashboardLoaded) {
            return _buildDashboard(context, state.dashboard);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, TeacherDashboard dashboard) {
    final theme = Theme.of(context);
    final profile = dashboard.profile;
    final earnings = dashboard.earnings;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TeacherBloc>().add(TeacherDashboardRequested());
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // ── Profile Summary Card ──
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30.r,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '${profile.firstName.isNotEmpty ? profile.firstName[0] : ''}${profile.lastName.isNotEmpty ? profile.lastName[0] : ''}'
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.firstName} ${profile.lastName}',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16.sp, color: Colors.amber),
                            SizedBox(width: 4.w),
                            Text(
                              '${profile.ratingAvg.toStringAsFixed(1)} (${profile.ratingCount} avis)',
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        _verificationBadge(profile.verificationStatus, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // ── Stats Row ──
          Row(
            children: [
              _statCard(
                icon: Icons.people_outline,
                label: 'Étudiants',
                value: '${profile.totalStudents}',
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 8.w),
              _statCard(
                icon: Icons.video_camera_front_outlined,
                label: 'Sessions',
                value: '${profile.totalSessions}',
                color: theme.colorScheme.secondary,
              ),
              SizedBox(width: 8.w),
              _statCard(
                icon: Icons.check_circle_outline,
                label: 'Complétion',
                value: '${(profile.completionRate * 100).toStringAsFixed(0)}%',
                color: Colors.green,
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // ── Earnings Card ──
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenus',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _earningItem(
                        'Ce mois',
                        '${earnings.monthEarnings.toStringAsFixed(0)} DA',
                      ),
                      _earningItem(
                        'Total',
                        '${earnings.totalEarnings.toStringAsFixed(0)} DA',
                      ),
                      _earningItem(
                        'Disponible',
                        '${earnings.availableBalance.toStringAsFixed(0)} DA',
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/teacher/earnings'),
                      child: const Text('Voir les détails'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // ── Quick Actions ──
          Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  icon: Icons.library_books_outlined,
                  label: 'Mes offres',
                  onTap: () => context.push('/teacher/offerings'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _actionCard(
                  icon: Icons.schedule_outlined,
                  label: 'Disponibilité',
                  onTap: () => context.push('/teacher/availability'),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // ── Upcoming Sessions ──
          Text(
            'Prochaines sessions',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (dashboard.upcomingSessions.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Center(
                  child: Text(
                    'Aucune session à venir',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            )
          else
            ...dashboard.upcomingSessions.map((s) => _sessionCard(s, theme)),

          SizedBox(height: 16.h),

          // ── Recent Reviews ──
          Text(
            'Avis récents',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (dashboard.recentReviews.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Center(
                  child: Text(
                    'Aucun avis pour le moment',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            )
          else
            ...dashboard.recentReviews.map((r) => _reviewCard(r, theme)),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }

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
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earningItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
          child: Column(
            children: [
              Icon(icon, size: 32.sp),
              SizedBox(height: 8.h),
              Text(label, style: TextStyle(fontSize: 13.sp)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verificationBadge(String status, ThemeData theme) {
    Color color;
    String label;
    switch (status) {
      case 'verified':
        color = Colors.green;
        label = 'Vérifié';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'En attente';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.sp, color: color),
      ),
    );
  }

  Widget _sessionCard(SessionBrief session, ThemeData theme) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(
          Icons.video_camera_front,
          color: theme.colorScheme.primary,
        ),
        title: Text(session.title),
        subtitle: Text(
          '${_formatDate(session.startTime)} · ${session.participantCount} participants',
          style: TextStyle(fontSize: 12.sp),
        ),
        trailing: _statusChip(session.status),
      ),
    );
  }

  Widget _reviewCard(ReviewBrief review, ThemeData theme) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.reviewerName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16.sp,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                review.reviewText!,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'scheduled':
        color = Colors.blue;
        break;
      case 'in_progress':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11.sp, color: color),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      '',
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc'
    ];
    return '${dt.day} ${months[dt.month]} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
