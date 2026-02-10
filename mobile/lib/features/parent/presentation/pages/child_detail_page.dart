import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/parent/domain/entities/child.dart' as ent;

class ChildDetailPage extends StatelessWidget {
  final ent.Child child;

  const ChildDetailPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${child.firstName} ${child.lastName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () => context.push(
              '/parent/children/${child.id}/edit',
              extra: child,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // ── Avatar ──────────────────────────────────────────
            CircleAvatar(
              radius: 48.r,
              backgroundColor: theme.colorScheme.primary,
              backgroundImage:
                  child.avatarUrl != null && child.avatarUrl!.isNotEmpty
                      ? NetworkImage(child.avatarUrl!)
                      : null,
              child: child.avatarUrl == null || child.avatarUrl!.isEmpty
                  ? Text(
                      '${child.firstName[0]}${child.lastName[0]}'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 32.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(height: 16.h),
            Text(
              '${child.firstName} ${child.lastName}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (child.levelName != null && child.levelName!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                child.levelName!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],

            SizedBox(height: 24.h),

            // ── Info cards ──────────────────────────────────────
            _infoTile(
              icon: Icons.school,
              label: 'Niveau',
              value: child.levelName ?? child.levelCode ?? '—',
            ),
            if (child.cycle != null && child.cycle!.isNotEmpty)
              _infoTile(
                icon: Icons.layers,
                label: 'Cycle',
                value: child.cycle!,
              ),
            if (child.filiere != null && child.filiere!.isNotEmpty)
              _infoTile(
                icon: Icons.category,
                label: 'Filière',
                value: child.filiere!,
              ),
            if (child.school != null && child.school!.isNotEmpty)
              _infoTile(
                icon: Icons.apartment,
                label: 'École',
                value: child.school!,
              ),
            if (child.dateOfBirth != null && child.dateOfBirth!.isNotEmpty)
              _infoTile(
                icon: Icons.cake,
                label: 'Date de naissance',
                value: child.dateOfBirth!,
              ),

            SizedBox(height: 32.h),

            // ── Progress button ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.trending_up),
                label: const Text('Voir la progression'),
                onPressed: () =>
                    context.push('/parent/children/${child.id}/progress'),
              ),
            ),

            SizedBox(height: 12.h),

            // ── Edit button ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier les informations'),
                onPressed: () => context.push(
                  '/parent/children/${child.id}/edit',
                  extra: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 22.sp, color: Colors.grey[600]),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
                SizedBox(height: 2.h),
                Text(value, style: TextStyle(fontSize: 15.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
