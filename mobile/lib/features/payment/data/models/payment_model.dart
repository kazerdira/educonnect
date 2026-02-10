import 'package:educonnect/features/payment/domain/entities/payment.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.payerId,
    required super.payerName,
    required super.recipientId,
    required super.recipientName,
    super.sessionId,
    super.courseId,
    super.subscriptionId,
    required super.amount,
    required super.currency,
    required super.paymentMethod,
    required super.status,
    required super.transactionRef,
    required super.description,
    super.receiptUrl,
    required super.createdAt,
    required super.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String? ?? '',
      payerId: json['payer_id'] as String? ?? '',
      payerName: json['payer_name'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? '',
      sessionId: json['session_id'] as String?,
      courseId: json['course_id'] as String?,
      subscriptionId: json['subscription_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'DZD',
      paymentMethod: json['payment_method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      transactionRef: json['transaction_ref'] as String? ?? '',
      description: json['description'] as String? ?? '',
      receiptUrl: json['receipt_url'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payer_id': payerId,
      'payer_name': payerName,
      'recipient_id': recipientId,
      'recipient_name': recipientName,
      if (sessionId != null) 'session_id': sessionId,
      if (courseId != null) 'course_id': courseId,
      if (subscriptionId != null) 'subscription_id': subscriptionId,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'status': status,
      'transaction_ref': transactionRef,
      'description': description,
      if (receiptUrl != null) 'receipt_url': receiptUrl,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.id,
    required super.studentId,
    required super.teacherId,
    required super.teacherName,
    required super.planType,
    required super.amount,
    required super.currency,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.autoRenew,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      planType: json['plan_type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'DZD',
      status: json['status'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      autoRenew: json['auto_renew'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'plan_type': planType,
      'amount': amount,
      'currency': currency,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'auto_renew': autoRenew,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
