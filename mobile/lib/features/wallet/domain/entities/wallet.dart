import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String id;
  final String teacherId;
  final double balance;
  final double totalPurchased;
  final double totalSpent;
  final double totalRefunded;
  final int groupStarsAvailable;
  final int privateStarsAvailable;
  final String createdAt;
  final String updatedAt;

  const Wallet({
    required this.id,
    required this.teacherId,
    required this.balance,
    required this.totalPurchased,
    required this.totalSpent,
    required this.totalRefunded,
    required this.groupStarsAvailable,
    required this.privateStarsAvailable,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class WalletTransaction extends Equatable {
  final String id;
  final String walletId;
  final String type; // purchase, star_deduction, refund
  final String status; // pending, completed, failed
  final double amount;
  final double balanceAfter;
  final String description;
  final String? packageId;
  final String? packageName;
  final String? paymentMethod;
  final String? providerRef;
  final String? enrollmentId;
  final String? seriesId;
  final String? seriesTitle;
  final String? adminNotes;
  final String createdAt;

  const WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.status,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.packageId,
    this.packageName,
    this.paymentMethod,
    this.providerRef,
    this.enrollmentId,
    this.seriesId,
    this.seriesTitle,
    this.adminNotes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}

class CreditPackage extends Equatable {
  final String id;
  final String name;
  final double amount;
  final double bonus;
  final double totalCredits;
  final int groupStars;
  final int privateStars;
  final bool isActive;
  final int sortOrder;

  const CreditPackage({
    required this.id,
    required this.name,
    required this.amount,
    required this.bonus,
    required this.totalCredits,
    required this.groupStars,
    required this.privateStars,
    required this.isActive,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [id];
}
