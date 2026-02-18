import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id;
  final String payerId;
  final String payerName;
  final String payeeId;
  final String payeeName;
  final String? sessionId;
  final String? courseId;
  final String? subscriptionId;
  final double amount;
  final double commission;
  final double netAmount;
  final String paymentMethod;
  final String status;
  final String? providerReference;
  final String? description;
  final double refundAmount;
  final String? refundReason;
  final String createdAt;
  final String updatedAt;

  const Transaction({
    required this.id,
    required this.payerId,
    required this.payerName,
    required this.payeeId,
    required this.payeeName,
    this.sessionId,
    this.courseId,
    this.subscriptionId,
    required this.amount,
    required this.commission,
    required this.netAmount,
    required this.paymentMethod,
    required this.status,
    this.providerReference,
    this.description,
    required this.refundAmount,
    this.refundReason,
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
  final int sessionsPerMonth;
  final int sessionsUsed;
  final double price;
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
    required this.sessionsPerMonth,
    required this.sessionsUsed,
    required this.price,
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
