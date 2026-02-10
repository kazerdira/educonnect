import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(AdminUsersRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des utilisateurs')),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<AdminBloc>().add(AdminUsersRequested()),
        child: BlocConsumer<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminUserSuspended) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur suspendu')),
              );
              context.read<AdminBloc>().add(AdminUsersRequested());
            }
            if (state is AdminUserUnsuspended) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Suspension levée')),
              );
              context.read<AdminBloc>().add(AdminUsersRequested());
            }
          },
          builder: (context, state) {
            if (state is AdminLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AdminError) {
              return Center(child: Text(state.message));
            }
            if (state is AdminUsersLoaded) {
              if (state.users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucun utilisateur',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.users.length,
                itemBuilder: (_, i) => _userCard(state.users[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _userCard(AdminUser user) {
    final Color statusColor = user.isSuspended
        ? Colors.red
        : (user.isActive ? Colors.green : Colors.grey);
    final String statusLabel =
        user.isSuspended ? 'Suspendu' : (user.isActive ? 'Actif' : 'Inactif');

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  child: Text(
                    user.firstName.isNotEmpty ? user.firstName[0] : '?',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w600),
                      ),
                      Text(user.email,
                          style:
                              TextStyle(fontSize: 13.sp, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _chip(user.role, Colors.indigo),
                SizedBox(width: 8.w),
                if (user.isVerified)
                  _chip('Vérifié', Colors.green)
                else
                  _chip('Non vérifié', Colors.orange),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user.isSuspended)
                  TextButton.icon(
                    onPressed: () => context.read<AdminBloc>().add(
                          AdminUnsuspendUserRequested(userId: user.id),
                        ),
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Lever la suspension'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _showSuspendDialog(user),
                    icon: const Icon(Icons.block, size: 18, color: Colors.red),
                    label: const Text('Suspendre',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.sp, color: color)),
    );
  }

  void _showSuspendDialog(AdminUser user) {
    final reasonCtrl = TextEditingController();
    final durationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspendre ${user.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Raison *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: durationCtrl,
              decoration: const InputDecoration(
                labelText: 'Durée (ex: 7d, 30d)',
                border: OutlineInputBorder(),
                hintText: 'Laisser vide pour permanent',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              context.read<AdminBloc>().add(
                    AdminSuspendUserRequested(
                      userId: user.id,
                      reason: reasonCtrl.text.trim(),
                      duration: durationCtrl.text.trim().isEmpty
                          ? null
                          : durationCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );
  }
}
