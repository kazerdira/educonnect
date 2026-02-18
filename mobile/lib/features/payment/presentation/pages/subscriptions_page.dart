import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/payment/domain/entities/payment.dart';
import 'package:educonnect/features/payment/presentation/bloc/payment_bloc.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<PaymentBloc>().add(SubscriptionsRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes abonnements')),
      body: BlocConsumer<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is SubscriptionCancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Abonnement annulé')),
            );
            context.read<PaymentBloc>().add(SubscriptionsRequested());
          }
          if (state is PaymentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is PaymentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SubscriptionsLoaded) {
            if (state.subscriptions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_membership_outlined,
                        size: 64.sp, color: Colors.grey),
                    SizedBox(height: 12.h),
                    const Text('Aucun abonnement'),
                  ],
                ),
              );
            }
            return _buildSubscriptionList(state.subscriptions, theme);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSubscriptionList(
      List<Subscription> subscriptions, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<PaymentBloc>().add(SubscriptionsRequested());
      },
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: subscriptions.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          final sub = subscriptions[index];
          return _SubscriptionCard(
            subscription: sub,
            theme: theme,
            onCancel: () => _confirmCancel(sub),
          );
        },
      ),
    );
  }

  void _confirmCancel(Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'abonnement ?'),
        content: Text(
          'Voulez-vous vraiment annuler votre abonnement '
          '${sub.planType} avec ${sub.teacherName} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<PaymentBloc>().add(
                    CancelSubscriptionRequested(subscriptionId: sub.id),
                  );
            },
            child:
                const Text('Oui, annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final ThemeData theme;
  final VoidCallback onCancel;

  const _SubscriptionCard({
    required this.subscription,
    required this.theme,
    required this.onCancel,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Actif';
      case 'cancelled':
      case 'canceled':
        return 'Annulé';
      case 'expired':
        return 'Expiré';
      case 'pending':
        return 'En attente';
      default:
        return status;
    }
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(subscription.status);
    final isActive = subscription.status.toLowerCase() == 'active';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: teacher name + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    subscription.teacherName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    _statusLabel(subscription.status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Plan type + amount
            Row(
              children: [
                Icon(Icons.card_membership, size: 16.sp, color: Colors.grey),
                SizedBox(width: 6.w),
                Text(
                  subscription.planType,
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  '${subscription.price.toStringAsFixed(0)} DA',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),

            // Date range
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                SizedBox(width: 6.w),
                Text(
                  '${_formatDate(subscription.startDate)} – ${_formatDate(subscription.endDate)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            SizedBox(height: 4.h),

            // Auto-renew info
            Row(
              children: [
                Icon(
                  subscription.autoRenew ? Icons.autorenew : Icons.block,
                  size: 14.sp,
                  color: subscription.autoRenew ? Colors.green : Colors.grey,
                ),
                SizedBox(width: 6.w),
                Text(
                  subscription.autoRenew
                      ? 'Renouvellement automatique'
                      : 'Pas de renouvellement auto',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

            // Cancel action
            if (isActive) ...[
              SizedBox(height: 10.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Annuler',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
