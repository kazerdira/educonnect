import 'package:educonnect/features/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:educonnect/features/wallet/domain/entities/wallet.dart';
import 'package:educonnect/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Wallet> getWallet() => remoteDataSource.getWallet();

  @override
  Future<WalletTransaction> buyCredits({
    required String packageId,
    required String paymentMethod,
    required String providerRef,
  }) =>
      remoteDataSource.buyCredits(
        packageId: packageId,
        paymentMethod: paymentMethod,
        providerRef: providerRef,
      );

  @override
  Future<List<WalletTransaction>> getTransactions({
    String? type,
    int page = 1,
    int limit = 20,
  }) =>
      remoteDataSource.getTransactions(
        type: type,
        page: page,
        limit: limit,
      );

  @override
  Future<List<CreditPackage>> getPackages() => remoteDataSource.getPackages();
}
