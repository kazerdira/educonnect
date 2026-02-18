import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/payment/domain/entities/payment.dart';
import 'package:educonnect/features/payment/presentation/bloc/payment_bloc.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  @override
  void initState() {
    super.initState();
    context.read<PaymentBloc>().add(PaymentHistoryRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des paiements')),
      body: BlocBuilder<PaymentBloc, PaymentState>(
        builder: (context, state) {
          if (state is PaymentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PaymentError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<PaymentBloc>()
                        .add(PaymentHistoryRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is PaymentHistoryLoaded) {
            if (state.transactions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64.sp, color: Colors.grey),
                    SizedBox(height: 12.h),
                    const Text('Aucune transaction'),
                  ],
                ),
              );
            }
            return _buildTransactionList(state.transactions, theme);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTransactionList(
      List<Transaction> transactions, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<PaymentBloc>().add(PaymentHistoryRequested());
      },
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (context, index) {
          final tx = transactions[index];
          return _TransactionCard(transaction: tx, theme: theme);
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final ThemeData theme;

  const _TransactionCard({required this.transaction, required this.theme});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'confirmed':
        return 'Confirmé';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échoué';
      case 'refunded':
        return 'Remboursé';
      default:
        return status;
    }
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy – HH:mm').format(date);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(transaction.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: description + amount
            Row(
              children: [
                Expanded(
                  child: Text(
                    (transaction.description ?? '').isNotEmpty
                        ? transaction.description!
                        : 'Paiement',
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${transaction.amount.toStringAsFixed(0)} DA',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Recipient
            Text(
              'À : ${transaction.payeeName}',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 4.h),
            // Method
            Text(
              'Méthode : ${transaction.paymentMethod}',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 8.h),
            // Bottom row: date + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(transaction.createdAt),
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    _statusLabel(transaction.status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
