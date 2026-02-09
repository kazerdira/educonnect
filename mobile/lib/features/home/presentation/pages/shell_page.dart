import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/home/presentation/pages/home_page.dart';
import 'package:educonnect/features/home/presentation/pages/sessions_tab.dart';
import 'package:educonnect/features/home/presentation/pages/profile_page.dart';

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
        final role = state is AuthAuthenticated ? state.user.role : 'student';
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
            page: const HomePage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
          ),
          _TabConfig(
            page: const SessionsTab(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.video_camera_front_outlined),
              activeIcon: Icon(Icons.video_camera_front),
              label: 'Mes Sessions',
            ),
          ),
          _TabConfig(
            page: const _PlaceholderTab(
              icon: Icons.menu_book_outlined,
              label: 'Gérez vos cours et ressources',
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
            page: const HomePage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
          ),
          _TabConfig(
            page: const _PlaceholderTab(
              icon: Icons.child_care_outlined,
              label: 'Gérez vos enfants et leur progression',
            ),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.child_care_outlined),
              activeIcon: Icon(Icons.child_care),
              label: 'Enfants',
            ),
          ),
          _TabConfig(
            page: const _PlaceholderTab(
              icon: Icons.search,
              label: 'Recherchez des enseignants',
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

      default: // student
        return [
          _TabConfig(
            page: const HomePage(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
          ),
          _TabConfig(
            page: const SessionsTab(),
            navItem: const BottomNavigationBarItem(
              icon: Icon(Icons.video_camera_front_outlined),
              activeIcon: Icon(Icons.video_camera_front),
              label: 'Sessions',
            ),
          ),
          _TabConfig(
            page: const _PlaceholderTab(
              icon: Icons.search,
              label: 'Trouvez des enseignants et des cours',
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
