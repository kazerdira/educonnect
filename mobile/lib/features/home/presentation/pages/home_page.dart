import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';

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
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour${user != null ? ', ${user.firstName}' : ''} 👋',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _getRoleSubtitle(user?.role),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 32.h),

                  // Placeholder cards
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16.h,
                      crossAxisSpacing: 16.w,
                      children: [
                        _buildFeatureCard(
                          context,
                          icon: Icons.video_camera_front,
                          label: 'Sessions',
                          color: const Color(0xFF1565C0),
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.menu_book,
                          label: 'Cours',
                          color: const Color(0xFF00897B),
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.search,
                          label: 'Rechercher',
                          color: const Color(0xFFFFA726),
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.bar_chart,
                          label: 'Progression',
                          color: const Color(0xFF7B1FA2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 15.sp),
            ),
          ],
        ),
      ),
    );
  }
}
