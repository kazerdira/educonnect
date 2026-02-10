import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(AdminAnalyticsRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord Admin')),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<AdminBloc>().add(AdminAnalyticsRequested()),
        child: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            if (state is AdminLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AdminError) {
              return Center(child: Text(state.message));
            }
            if (state is AdminAnalyticsLoaded) {
              return _buildDashboard(state.overview, theme);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(AnalyticsOverview o, ThemeData theme) {
    final currencyFmt =
        NumberFormat.currency(locale: 'fr_DZ', symbol: 'DA', decimalDigits: 0);

    final cards = <_StatCard>[
      _StatCard(
        icon: Icons.people,
        label: 'Utilisateurs',
        value: '${o.totalUsers}',
        color: Colors.blue,
      ),
      _StatCard(
        icon: Icons.school,
        label: 'Enseignants',
        value: '${o.totalTeachers}',
        color: Colors.indigo,
      ),
      _StatCard(
        icon: Icons.person,
        label: 'Étudiants',
        value: '${o.totalStudents}',
        color: Colors.teal,
      ),
      _StatCard(
        icon: Icons.family_restroom,
        label: 'Parents',
        value: '${o.totalParents}',
        color: Colors.orange,
      ),
      _StatCard(
        icon: Icons.video_call,
        label: 'Sessions',
        value: '${o.totalSessions}',
        color: Colors.purple,
      ),
      _StatCard(
        icon: Icons.play_circle,
        label: 'Sessions actives',
        value: '${o.activeSessions}',
        color: Colors.green,
      ),
      _StatCard(
        icon: Icons.menu_book,
        label: 'Cours',
        value: '${o.totalCourses}',
        color: Colors.cyan,
      ),
      _StatCard(
        icon: Icons.attach_money,
        label: 'Revenu total',
        value: currencyFmt.format(o.totalRevenue),
        color: Colors.amber,
      ),
      _StatCard(
        icon: Icons.verified_user,
        label: 'Vérifications en attente',
        value: '${o.pendingVerifications}',
        color: Colors.deepOrange,
      ),
      _StatCard(
        icon: Icons.report_problem,
        label: 'Litiges ouverts',
        value: '${o.openDisputes}',
        color: Colors.red,
      ),
    ];

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Text(
          'Vue d\'ensemble',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 1.5,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _buildCard(cards[i], theme),
        ),
      ],
    );
  }

  Widget _buildCard(_StatCard card, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(card.icon, color: card.color, size: 28.sp),
            SizedBox(height: 4.h),
            Text(
              card.value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: card.color,
              ),
            ),
            Text(
              card.label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
