import 'package:educonnect/features/teacher/domain/entities/earnings.dart';

class EarningsModel extends Earnings {
  const EarningsModel({
    super.totalEarnings,
    super.monthEarnings,
    super.availableBalance,
    super.transactions,
  });

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    return EarningsModel(
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      monthEarnings: (json['month_earnings'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0.0,
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) =>
                  TransactionSummaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TransactionSummaryModel extends TransactionSummary {
  const TransactionSummaryModel({
    required super.id,
    required super.payerName,
    required super.amount,
    super.commission,
    required super.netAmount,
    required super.paymentMethod,
    required super.status,
    required super.createdAt,
  });

  factory TransactionSummaryModel.fromJson(Map<String, dynamic> json) {
    return TransactionSummaryModel(
      id: json['id'] as String? ?? '',
      payerName: json['payer_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
