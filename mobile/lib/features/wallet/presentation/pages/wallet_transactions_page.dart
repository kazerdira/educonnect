import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/wallet/domain/entities/wallet.dart';
import 'package:educonnect/features/wallet/presentation/bloc/wallet_bloc.dart';

class WalletTransactionsPage extends StatefulWidget {
  const WalletTransactionsPage({super.key});

  @override
  State<WalletTransactionsPage> createState() => _WalletTransactionsPageState();
}

class _WalletTransactionsPageState extends State<WalletTransactionsPage> {
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    context
        .read<WalletBloc>()
        .add(WalletTransactionsRequested(type: _filterType));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterType = value);
              _loadTransactions();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Tout')),
              const PopupMenuItem(value: 'purchase', child: Text('Achats')),
              const PopupMenuItem(
                  value: 'star_deduction', child: Text('Étoiles dépensées')),
              const PopupMenuItem(
                  value: 'refund', child: Text('Remboursements')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WalletError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: _loadTransactions,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is WalletTransactionsLoaded) {
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
            return _buildTransactionList(state.transactions);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTransactionList(List<WalletTransaction> transactions) {
    return RefreshIndicator(
      onRefresh: () async => _loadTransactions(),
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (context, index) {
          return _WalletTransactionCard(transaction: transactions[index]);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Transaction Card
// ═══════════════════════════════════════════════════════════════

class _WalletTransactionCard extends StatelessWidget {
  final WalletTransaction transaction;

  const _WalletTransactionCard({required this.transaction});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'purchase':
        return Icons.add_circle;
      case 'star_deduction':
        return Icons.star;
      case 'refund':
        return Icons.replay;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'purchase':
        return AppTheme.success;
      case 'star_deduction':
        return AppTheme.accent;
      case 'refund':
        return AppTheme.primaryLight;
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'purchase':
        return 'Achat';
      case 'star_deduction':
        return 'Étoile dépensée';
      case 'refund':
        return 'Remboursement';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return AppTheme.error;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Complété';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échoué';
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit =
        transaction.type == 'purchase' || transaction.type == 'refund';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: _typeColor(transaction.type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _typeIcon(transaction.type),
              color: _typeColor(transaction.type),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(transaction.type),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: _statusColor(transaction.status)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        _statusLabel(transaction.status),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(transaction.status),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _formatDate(transaction.createdAt),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isCredit ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
