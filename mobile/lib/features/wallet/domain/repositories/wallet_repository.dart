import 'package:educonnect/features/wallet/domain/entities/wallet.dart';

abstract class WalletRepository {
  Future<Wallet> getWallet();

  Future<WalletTransaction> buyCredits({
    required String packageId,
    required String paymentMethod,
    required String providerRef,
  });

  Future<List<WalletTransaction>> getTransactions({
    String? type,
    int page = 1,
    int limit = 20,
  });

  Future<List<CreditPackage>> getPackages();
}
