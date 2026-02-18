import '../../domain/entities/platform_fee.dart';

class PlatformFeeModel extends PlatformFee {
  const PlatformFeeModel({
    required super.id,
    required super.seriesId,
    required super.seriesTitle,
    required super.teacherId,
    required super.amount,
    required super.status,
    super.providerRef,
    super.description,
    required super.enrolledCount,
    required super.totalSessions,
    required super.durationHours,
    required super.feeRate,
    required super.createdAt,
    super.paidAt,
  });

  factory PlatformFeeModel.fromJson(Map<String, dynamic> json) {
    return PlatformFeeModel(
      id: json['id'] as String,
      seriesId: json['series_id'] as String,
      seriesTitle: json['series_title'] as String? ?? '',
      teacherId: json['teacher_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      providerRef: json['provider_ref'] as String?,
      description: json['description'] as String?,
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0.0,
      feeRate: (json['fee_rate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'series_id': seriesId,
      'series_title': seriesTitle,
      'teacher_id': teacherId,
      'amount': amount,
      'status': status,
      'provider_ref': providerRef,
      'description': description,
      'enrolled_count': enrolledCount,
      'total_sessions': totalSessions,
      'duration_hours': durationHours,
      'fee_rate': feeRate,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
    };
  }
}

/// Request model for confirming fee payment
class ConfirmFeePaymentRequest {
  final String providerRef;

  const ConfirmFeePaymentRequest({
    required this.providerRef,
  });

  Map<String, dynamic> toJson() {
    return {
      'provider_ref': providerRef,
    };
  }
}
