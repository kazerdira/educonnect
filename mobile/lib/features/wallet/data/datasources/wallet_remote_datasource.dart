import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/wallet/data/models/wallet_model.dart';

class WalletRemoteDataSource {
  final ApiClient apiClient;

  WalletRemoteDataSource({required this.apiClient});

  /// GET /wallet
  Future<WalletModel> getWallet() async {
    final response = await apiClient.get(ApiConstants.wallet);
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from getWallet');
    return WalletModel.fromJson(data);
  }

  /// POST /wallet/buy
  Future<WalletTransactionModel> buyCredits({
    required String packageId,
    required String paymentMethod,
    required String providerRef,
  }) async {
    final response = await apiClient.post(
      ApiConstants.walletBuy,
      data: {
        'package_id': packageId,
        'payment_method': paymentMethod,
        'provider_ref': providerRef,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from buyCredits');
    return WalletTransactionModel.fromJson(data);
  }

  /// GET /wallet/transactions
  Future<List<WalletTransactionModel>> getTransactions({
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    final response = await apiClient.get(
      ApiConstants.walletTransactions,
      queryParameters: queryParams,
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /wallet/packages
  Future<List<CreditPackageModel>> getPackages() async {
    final response = await apiClient.get(ApiConstants.walletPackages);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => CreditPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
