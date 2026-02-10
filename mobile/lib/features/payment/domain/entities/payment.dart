import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id;
  final String payerId;
  final String payerName;
  final String recipientId;
  final String recipientName;
  final String? sessionId;
  final String? courseId;
  final String? subscriptionId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String status;
  final String transactionRef;
  final String description;
  final String? receiptUrl;
  final String createdAt;
  final String updatedAt;

  const Transaction({
    required this.id,
    required this.payerId,
    required this.payerName,
    required this.recipientId,
    required this.recipientName,
    this.sessionId,
    this.courseId,
    this.subscriptionId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.transactionRef,
    required this.description,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class Subscription extends Equatable {
  final String id;
  final String studentId;
  final String teacherId;
  final String teacherName;
  final String planType;
  final double amount;
  final String currency;
  final String status;
  final String startDate;
  final String endDate;
  final bool autoRenew;
  final String createdAt;
  final String updatedAt;

  const Subscription({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.teacherName,
    required this.planType,
    required this.amount,
    required this.currency,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.autoRenew,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}
