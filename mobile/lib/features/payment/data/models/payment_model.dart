import 'package:educonnect/features/payment/domain/entities/payment.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.payerId,
    required super.payerName,
    required super.payeeId,
    required super.payeeName,
    super.sessionId,
    super.courseId,
    super.subscriptionId,
    required super.amount,
    required super.commission,
    required super.netAmount,
    required super.paymentMethod,
    required super.status,
    super.providerReference,
    super.description,
    required super.refundAmount,
    super.refundReason,
    required super.createdAt,
    required super.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String? ?? '',
      payerId: json['payer_id'] as String? ?? '',
      payerName: json['payer_name'] as String? ?? '',
      payeeId: json['payee_id'] as String? ?? '',
      payeeName: json['payee_name'] as String? ?? '',
      sessionId: json['session_id'] as String?,
      courseId: json['course_id'] as String?,
      subscriptionId: json['subscription_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      providerReference: json['provider_reference'] as String?,
      description: json['description'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      refundReason: json['refund_reason'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payer_id': payerId,
      'payer_name': payerName,
      'payee_id': payeeId,
      'payee_name': payeeName,
      if (sessionId != null) 'session_id': sessionId,
      if (courseId != null) 'course_id': courseId,
      if (subscriptionId != null) 'subscription_id': subscriptionId,
      'amount': amount,
      'commission': commission,
      'net_amount': netAmount,
      'payment_method': paymentMethod,
      'status': status,
      if (providerReference != null) 'provider_reference': providerReference,
      if (description != null) 'description': description,
      'refund_amount': refundAmount,
      if (refundReason != null) 'refund_reason': refundReason,
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
    required super.sessionsPerMonth,
    required super.sessionsUsed,
    required super.price,
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
      sessionsPerMonth: json['sessions_per_month'] as int? ?? 0,
      sessionsUsed: json['sessions_used'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
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
      'sessions_per_month': sessionsPerMonth,
      'sessions_used': sessionsUsed,
      'price': price,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'auto_renew': autoRenew,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
