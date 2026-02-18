import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/home/presentation/pages/profile_page.dart';
import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_dashboard_page.dart';
import 'package:educonnect/features/search/presentation/bloc/search_bloc.dart';
import 'package:educonnect/features/search/presentation/pages/search_page.dart';
import 'package:educonnect/features/session/presentation/bloc/session_bloc.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';
import 'package:educonnect/features/session/presentation/pages/session_list_page.dart';
import 'package:educonnect/features/session/presentation/pages/series_list_page.dart';
import 'package:educonnect/features/session/presentation/pages/invitations_page.dart';
import 'package:educonnect/features/session/presentation/pages/browse_series_page.dart';
import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:educonnect/features/parent/presentation/pages/parent_dashboard_page.dart';
import 'package:educonnect/features/parent/presentation/pages/children_list_page.dart';
import 'package:educonnect/features/course/presentation/bloc/course_bloc.dart';
import 'package:educonnect/features/course/presentation/pages/course_list_page.dart';
import 'package:educonnect/features/student/presentation/bloc/student_bloc.dart';
import 'package:educonnect/features/student/presentation/pages/student_dashboard_page.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_users_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_verifications_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_disputes_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Don't render any tab content when unauthenticated
        // (avoids firing API calls without a token during logout)
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = state.user.role;
        final tabs = _tabsForRole(role);

        // Reset index if it's out of range (e.g. role changed)
        if (_currentIndex >= tabs.length) {
          _currentIndex = 0;
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: tabs.map((t) => t.page).toList(),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            items: tabs.map((t) => t.navItem).toList(),
          ),
        );
      },
    );
  }

  List<_TabConfig> _tabsForRole(String role) {
    switch (role) {
      case 'teacher':
        return [
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<TeacherBloc>(),
              child: const TeacherDashboardPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Tableau de bord',
            ),
          ),
          _TabConfig(
            page: const SeriesListPage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_month_outlined),
              activeIcon: Icon(Icons.calendar_view_month),
              label: 'Séries',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<CourseBloc>(),
              child: const CourseListPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Cours',
            ),
          ),
          _TabConfig(
            page: const ProfilePage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ),
        ];

      case 'parent':
        return [
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<ParentBloc>(),
              child: const ParentDashboardPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<ParentBloc>(),
              child: const ChildrenListPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.child_care_outlined),
              activeIcon: Icon(Icons.child_care),
              label: 'Enfants',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<SearchBloc>(),
              child: const SearchPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Rechercher',
            ),
          ),
          _TabConfig(
            page: const ProfilePage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ),
        ];

      case 'admin':
        return [
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<AdminBloc>(),
              child: const AdminDashboardPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Tableau de bord',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<AdminBloc>(),
              child: const AdminUsersPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.people_outlined),
              activeIcon: Icon(Icons.people),
              label: 'Utilisateurs',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<AdminBloc>(),
              child: const AdminVerificationsPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.verified_outlined),
              activeIcon: Icon(Icons.verified),
              label: 'Vérifications',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<AdminBloc>(),
              child: const AdminDisputesPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.gavel_outlined),
              activeIcon: Icon(Icons.gavel),
              label: 'Litiges',
            ),
          ),
        ];

      default: // student
        return [
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<StudentBloc>(),
              child: const StudentDashboardPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<SeriesBloc>(),
              child: const BrowseSeriesPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explorer',
            ),
          ),
          _TabConfig(
            page: const InvitationsPage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.mail_outline),
              activeIcon: Icon(Icons.mail),
              label: 'Invitations',
            ),
          ),
          _TabConfig(
            page: BlocProvider(
              create: (_) => getIt<SearchBloc>(),
              child: const SearchPage(),
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Rechercher',
            ),
          ),
          _TabConfig(
            page: const ProfilePage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ),
        ];
    }
  }
}

// ── Helper classes ───────────────────────────────────────────────

class _TabConfig {
  final Widget page;
  final BottomNavigationBarItem navItem;

  const _TabConfig({required this.page, required this.navItem});
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
