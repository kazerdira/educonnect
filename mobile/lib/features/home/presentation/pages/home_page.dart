import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';

/// Dashboard tab – shown inside [ShellPage] as the first tab.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('EduConnect'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // TODO: Navigate to notifications
                },
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.all(24.w),
              children: [
                // ── Greeting ──────────────────────────────────
                Text(
                  'Bonjour${user != null ? ', ${user.firstName}' : ''} 👋',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 4.h),
                Text(
                  _getRoleSubtitle(user?.role),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                SizedBox(height: 28.h),

                // ── Quick-action cards ────────────────────────
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14.h,
                  crossAxisSpacing: 14.w,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _cardsForRole(user?.role),
                ),

                SizedBox(height: 28.h),

                // ── Upcoming section (placeholder) ────────────
                Text(
                  'Prochaines sessions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12.h),
                _EmptyHint(
                  icon: Icons.event_outlined,
                  message: 'Aucune session prévue pour le moment',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Role helpers ──────────────────────────────────────────────

  String _getRoleSubtitle(String? role) {
    switch (role) {
      case 'teacher':
        return 'Bienvenue dans votre espace enseignant';
      case 'parent':
        return 'Suivez la progression de vos enfants';
      case 'student':
        return 'Prêt à apprendre aujourd\'hui ?';
      default:
        return 'Bienvenue sur EduConnect';
    }
  }

  List<Widget> _cardsForRole(String? role) {
    switch (role) {
      case 'teacher':
        return [
          _FeatureCard(
              icon: Icons.video_camera_front,
              label: 'Mes Sessions',
              color: AppTheme.primary),
          _FeatureCard(
              icon: Icons.menu_book,
              label: 'Mes Cours',
              color: AppTheme.secondary),
          _FeatureCard(
              icon: Icons.star_outline, label: 'Avis', color: AppTheme.accent),
          _FeatureCard(
              icon: Icons.bar_chart,
              label: 'Revenus',
              color: const Color(0xFF7B1FA2)),
        ];
      case 'parent':
        return [
          _FeatureCard(
              icon: Icons.child_care,
              label: 'Mes Enfants',
              color: AppTheme.primary),
          _FeatureCard(
              icon: Icons.search,
              label: 'Rechercher',
              color: AppTheme.secondary),
          _FeatureCard(
              icon: Icons.payment, label: 'Paiements', color: AppTheme.accent),
          _FeatureCard(
              icon: Icons.bar_chart,
              label: 'Progression',
              color: const Color(0xFF7B1FA2)),
        ];
      default: // student
        return [
          _FeatureCard(
              icon: Icons.video_camera_front,
              label: 'Sessions',
              color: AppTheme.primary),
          _FeatureCard(
              icon: Icons.menu_book, label: 'Cours', color: AppTheme.secondary),
          _FeatureCard(
              icon: Icons.search, label: 'Rechercher', color: AppTheme.accent),
          _FeatureCard(
              icon: Icons.bar_chart,
              label: 'Progression',
              color: const Color(0xFF7B1FA2)),
        ];
    }
  }
}

// ── Reusable feature card ────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to feature
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty hint widget ────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40.sp, color: AppTheme.textSecondary),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
