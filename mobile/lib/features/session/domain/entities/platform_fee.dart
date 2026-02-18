import 'package:equatable/equatable.dart';

/// Represents a platform fee that teacher must pay
class PlatformFee extends Equatable {
  final String id;
  final String seriesId;
  final String seriesTitle;
  final String teacherId;
  final double amount;
  final String status; // pending, completed, verified
  final String? providerRef;
  final String? description;
  final int enrolledCount;
  final int totalSessions;
  final double durationHours;
  final double feeRate;
  final DateTime createdAt;
  final DateTime? paidAt;

  const PlatformFee({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    required this.teacherId,
    required this.amount,
    required this.status,
    this.providerRef,
    this.description,
    required this.enrolledCount,
    required this.totalSessions,
    required this.durationHours,
    required this.feeRate,
    required this.createdAt,
    this.paidAt,
  });

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'completed' || status == 'paid';
  bool get isVerified => status == 'verified';
  bool get needsPayment => status == 'pending';

  @override
  List<Object?> get props => [
        id,
        seriesId,
        seriesTitle,
        teacherId,
        amount,
        status,
        providerRef,
        description,
        enrolledCount,
        totalSessions,
        durationHours,
        feeRate,
        createdAt,
        paidAt,
      ];

  /// Platform fee rates
  static const double groupFeePerHourPerStudent = 50.0; // DA
  static const double individualFeePerHour = 120.0; // DA
  static const String currency = 'DZD';

  /// Calculate estimated fee for group sessions
  static double calculateGroupFee({
    required int students,
    required int sessions,
    required double hoursPerSession,
  }) {
    return groupFeePerHourPerStudent * students * sessions * hoursPerSession;
  }

  /// Calculate estimated fee for individual sessions
  static double calculateIndividualFee({
    required int sessions,
    required double hoursPerSession,
  }) {
    return individualFeePerHour * sessions * hoursPerSession;
  }
}
