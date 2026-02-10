import 'package:equatable/equatable.dart';

class Earnings extends Equatable {
  final double totalEarnings;
  final double monthEarnings;
  final double availableBalance;
  final List<TransactionSummary> transactions;

  const Earnings({
    this.totalEarnings = 0.0,
    this.monthEarnings = 0.0,
    this.availableBalance = 0.0,
    this.transactions = const [],
  });

  @override
  List<Object?> get props => [totalEarnings, monthEarnings, availableBalance];
}

class TransactionSummary extends Equatable {
  final String id;
  final String payerName;
  final double amount;
  final double commission;
  final double netAmount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  const TransactionSummary({
    required this.id,
    required this.payerName,
    required this.amount,
    this.commission = 0.0,
    required this.netAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, amount, status];
}
