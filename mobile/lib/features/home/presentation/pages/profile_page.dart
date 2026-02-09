import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        return Scaffold(
          appBar: AppBar(title: const Text('Mon Profil')),
          body: user == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.all(24.w),
                  children: [
                    // ── Avatar + Name ──────────────────────────
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48.r,
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            child: Text(
                              _initials(user.firstName, user.lastName),
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            '${user.firstName} ${user.lastName}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(user.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              _roleLabel(user.role),
                              style: TextStyle(
                                color: _roleColor(user.role),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // ── Info Cards ─────────────────────────────
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user.email,
                    ),
                    _InfoTile(
                      icon: Icons.location_on_outlined,
                      label: 'Wilaya',
                      value: user.wilaya.isNotEmpty ? user.wilaya : '—',
                    ),
                    _InfoTile(
                      icon: Icons.language,
                      label: 'Langue',
                      value: _languageLabel(user.language),
                    ),
                    _InfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Membre depuis',
                      value: _formatDate(user.createdAt),
                    ),

                    SizedBox(height: 32.h),

                    // ── Actions ────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: navigate to edit profile
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier le profil'),
                    ),

                    SizedBox(height: 12.h),

                    ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Se déconnecter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'teacher':
        return 'Enseignant';
      case 'student':
        return 'Élève';
      case 'parent':
        return 'Parent';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'teacher':
        return AppTheme.primary;
      case 'student':
        return AppTheme.secondary;
      case 'parent':
        return AppTheme.accent;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _languageLabel(String lang) {
    switch (lang) {
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      default:
        return lang.isNotEmpty ? lang : '—';
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: const Text('Déconnexion',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Info Tile ──────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
