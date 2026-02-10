import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';

class AdminVerificationsPage extends StatefulWidget {
  const AdminVerificationsPage({super.key});

  @override
  State<AdminVerificationsPage> createState() => _AdminVerificationsPageState();
}

class _AdminVerificationsPageState extends State<AdminVerificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(AdminVerificationsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes de vérification')),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<AdminBloc>().add(AdminVerificationsRequested()),
        child: BlocConsumer<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminVerificationApproved) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vérification approuvée')),
              );
              context.read<AdminBloc>().add(AdminVerificationsRequested());
            }
            if (state is AdminVerificationRejected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vérification rejetée')),
              );
              context.read<AdminBloc>().add(AdminVerificationsRequested());
            }
          },
          builder: (context, state) {
            if (state is AdminLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AdminError) {
              return Center(child: Text(state.message));
            }
            if (state is AdminVerificationsLoaded) {
              if (state.verifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucune demande',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.verifications.length,
                itemBuilder: (_, i) =>
                    _verificationCard(state.verifications[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _verificationCard(Verification v) {
    final Color statusColor = switch (v.status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };
    final String statusLabel = switch (v.status) {
      'approved' => 'Approuvé',
      'rejected' => 'Rejeté',
      _ => 'En attente',
    };

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.indigo, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.userName,
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w600),
                      ),
                      Text(v.documentType,
                          style: TextStyle(
                              fontSize: 13.sp, color: Colors.grey[600])),
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
            Text('Soumis le ${v.createdAt}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
            if (v.reviewNote != null) ...[
              SizedBox(height: 4.h),
              Text('Note: ${v.reviewNote}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
            ],
            if (v.status == 'pending') ...[
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(v),
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    label: const Text('Rejeter',
                        style: TextStyle(color: Colors.red)),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton.icon(
                    onPressed: () => context.read<AdminBloc>().add(
                          AdminApproveVerificationRequested(
                              verificationId: v.id),
                        ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approuver'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Verification v) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rejeter la vérification de ${v.userName}'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note de rejet',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AdminBloc>().add(
                    AdminRejectVerificationRequested(
                      verificationId: v.id,
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }
}
