import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';

class AdminDisputesPage extends StatefulWidget {
  const AdminDisputesPage({super.key});

  @override
  State<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends State<AdminDisputesPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(AdminDisputesRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Litiges')),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<AdminBloc>().add(AdminDisputesRequested()),
        child: BlocConsumer<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminDisputeResolved) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Litige résolu')),
              );
              context.read<AdminBloc>().add(AdminDisputesRequested());
            }
          },
          builder: (context, state) {
            if (state is AdminLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AdminError) {
              return Center(child: Text(state.message));
            }
            if (state is AdminDisputesLoaded) {
              if (state.disputes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel_outlined,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucun litige',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.disputes.length,
                itemBuilder: (_, i) => _disputeCard(state.disputes[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _disputeCard(Dispute d) {
    final Color statusColor = switch (d.status) {
      'resolved' => Colors.green,
      'dismissed' => Colors.grey,
      _ => Colors.orange,
    };
    final String statusLabel = switch (d.status) {
      'resolved' => 'Résolu',
      'dismissed' => 'Rejeté',
      _ => 'Ouvert',
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
                Icon(Icons.report, color: Colors.red, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    d.type,
                    style:
                        TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
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
            _infoRow('Signalé par', d.reporterName),
            _infoRow('Signalé contre', d.reportedName),
            SizedBox(height: 4.h),
            Text(
              d.description,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (d.resolution != null) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Text('Résolution: ${d.resolution}',
                    style:
                        TextStyle(fontSize: 12.sp, color: Colors.green[800])),
              ),
            ],
            if (d.status != 'resolved' && d.status != 'dismissed') ...[
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _showResolveDialog(d),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Résoudre'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }

  void _showResolveDialog(Dispute d) {
    final resolutionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résoudre le litige'),
        content: TextField(
          controller: resolutionCtrl,
          decoration: const InputDecoration(
            labelText: 'Résolution *',
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
              if (resolutionCtrl.text.trim().isEmpty) return;
              context.read<AdminBloc>().add(
                    AdminResolveDisputeRequested(
                      disputeId: d.id,
                      resolution: resolutionCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}
