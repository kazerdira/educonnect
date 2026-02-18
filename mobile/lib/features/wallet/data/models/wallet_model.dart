import 'package:educonnect/features/wallet/domain/entities/wallet.dart';

class WalletModel extends Wallet {
  const WalletModel({
    required super.id,
    required super.teacherId,
    required super.balance,
    required super.totalPurchased,
    required super.totalSpent,
    required super.totalRefunded,
    required super.groupStarsAvailable,
    required super.privateStarsAvailable,
    required super.createdAt,
    required super.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      totalPurchased: (json['total_purchased'] as num?)?.toDouble() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      totalRefunded: (json['total_refunded'] as num?)?.toDouble() ?? 0,
      groupStarsAvailable: json['group_stars_available'] as int? ?? 0,
      privateStarsAvailable: json['private_stars_available'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'balance': balance,
      'total_purchased': totalPurchased,
      'total_spent': totalSpent,
      'total_refunded': totalRefunded,
      'group_stars_available': groupStarsAvailable,
      'private_stars_available': privateStarsAvailable,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class WalletTransactionModel extends WalletTransaction {
  const WalletTransactionModel({
    required super.id,
    required super.walletId,
    required super.type,
    required super.status,
    required super.amount,
    required super.balanceAfter,
    required super.description,
    super.packageId,
    super.packageName,
    super.paymentMethod,
    super.providerRef,
    super.enrollmentId,
    super.seriesId,
    super.seriesTitle,
    super.adminNotes,
    required super.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String? ?? '',
      walletId: json['wallet_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      packageId: json['package_id'] as String?,
      packageName: json['package_name'] as String?,
      paymentMethod: json['payment_method'] as String?,
      providerRef: json['provider_ref'] as String?,
      enrollmentId: json['enrollment_id'] as String?,
      seriesId: json['series_id'] as String?,
      seriesTitle: json['series_title'] as String?,
      adminNotes: json['admin_notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type,
      'status': status,
      'amount': amount,
      'balance_after': balanceAfter,
      'description': description,
      if (packageId != null) 'package_id': packageId,
      if (packageName != null) 'package_name': packageName,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (providerRef != null) 'provider_ref': providerRef,
      if (enrollmentId != null) 'enrollment_id': enrollmentId,
      if (seriesId != null) 'series_id': seriesId,
      if (seriesTitle != null) 'series_title': seriesTitle,
      if (adminNotes != null) 'admin_notes': adminNotes,
      'created_at': createdAt,
    };
  }
}

class CreditPackageModel extends CreditPackage {
  const CreditPackageModel({
    required super.id,
    required super.name,
    required super.amount,
    required super.bonus,
    required super.totalCredits,
    required super.groupStars,
    required super.privateStars,
    required super.isActive,
    required super.sortOrder,
  });

  factory CreditPackageModel.fromJson(Map<String, dynamic> json) {
    return CreditPackageModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
      totalCredits: (json['total_credits'] as num?)?.toDouble() ?? 0,
      groupStars: json['group_stars'] as int? ?? 0,
      privateStars: json['private_stars'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'bonus': bonus,
      'total_credits': totalCredits,
      'group_stars': groupStars,
      'private_stars': privateStars,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
