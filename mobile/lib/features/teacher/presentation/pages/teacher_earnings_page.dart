import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/teacher/domain/entities/earnings.dart';

class TeacherEarningsPage extends StatefulWidget {
  const TeacherEarningsPage({super.key});

  @override
  State<TeacherEarningsPage> createState() => _TeacherEarningsPageState();
}

class _TeacherEarningsPageState extends State<TeacherEarningsPage> {
  @override
  void initState() {
    super.initState();
    context.read<TeacherBloc>().add(TeacherEarningsRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes revenus')),
      body: BlocBuilder<TeacherBloc, TeacherState>(
        builder: (context, state) {
          if (state is TeacherLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TeacherError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<TeacherBloc>()
                        .add(TeacherEarningsRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is TeacherEarningsLoaded) {
            return _buildEarnings(state.earnings, theme);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEarnings(Earnings earnings, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<TeacherBloc>().add(TeacherEarningsRequested());
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Summary cards
          Row(
            children: [
              _summaryCard(
                'Total',
                '${earnings.totalEarnings.toStringAsFixed(0)} DA',
                Colors.blue,
                Icons.account_balance_wallet_outlined,
              ),
              SizedBox(width: 8.w),
              _summaryCard(
                'Ce mois',
                '${earnings.monthEarnings.toStringAsFixed(0)} DA',
                Colors.green,
                Icons.trending_up,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Card(
            color: theme.colorScheme.primary.withOpacity(0.05),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(Icons.account_balance,
                      color: theme.colorScheme.primary, size: 32.sp),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde disponible',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${earnings.availableBalance.toStringAsFixed(0)} DA',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24.h),

          // Transactions
          Text(
            'Historique des transactions',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),

          if (earnings.transactions.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Center(
                  child: Text(
                    'Aucune transaction',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                  ),
                ),
              ),
            )
          else
            ...earnings.transactions.map((t) => _transactionCard(t, theme)),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24.sp),
              SizedBox(height: 8.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionCard(TransactionSummary t, ThemeData theme) {
    Color statusColor;
    switch (t.status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'refunded':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            t.status == 'completed'
                ? Icons.check
                : t.status == 'refunded'
                    ? Icons.undo
                    : Icons.hourglass_empty,
            color: statusColor,
            size: 20.sp,
          ),
        ),
        title: Text(t.payerName),
        subtitle: Text(
          '${_formatDate(t.createdAt)} · ${t.paymentMethod}',
          style: TextStyle(fontSize: 12.sp),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+${t.netAmount.toStringAsFixed(0)} DA',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            if (t.commission > 0)
              Text(
                '-${t.commission.toStringAsFixed(0)} com.',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
