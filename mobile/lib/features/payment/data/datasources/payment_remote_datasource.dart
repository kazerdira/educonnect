import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/payment/data/models/payment_model.dart';

class PaymentRemoteDataSource {
  final ApiClient apiClient;

  PaymentRemoteDataSource({required this.apiClient});

  /// POST /payments/initiate
  Future<TransactionModel> initiatePayment({
    required String payeeId,
    String? sessionId,
    String? courseId,
    required double amount,
    required String paymentMethod,
    String? description,
  }) async {
    final response = await apiClient.post(
      ApiConstants.initiatePayment,
      data: {
        'payee_id': payeeId,
        if (sessionId != null) 'session_id': sessionId,
        if (courseId != null) 'course_id': courseId,
        'amount': amount,
        'payment_method': paymentMethod,
        if (description != null) 'description': description,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from initiatePayment');
    return TransactionModel.fromJson(data);
  }

  /// POST /payments/confirm
  Future<TransactionModel> confirmPayment({
    required String transactionId,
    required String providerReference,
  }) async {
    final response = await apiClient.post(
      ApiConstants.confirmPayment,
      data: {
        'transaction_id': transactionId,
        'provider_reference': providerReference,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from confirmPayment');
    return TransactionModel.fromJson(data);
  }

  /// GET /payments/history
  Future<List<TransactionModel>> getPaymentHistory() async {
    final response = await apiClient.get(ApiConstants.paymentHistory);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /payments/refund
  Future<TransactionModel> refundPayment(
    String transactionId, {
    required String reason,
    required double amount,
  }) async {
    final response = await apiClient.post(
      ApiConstants.refundPayment,
      data: {
        'transaction_id': transactionId,
        'amount': amount,
        'reason': reason,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from refundPayment');
    return TransactionModel.fromJson(data);
  }

  /// POST /subscriptions
  Future<SubscriptionModel> createSubscription({
    required String teacherId,
    required String planType,
    required int sessionsPerMonth,
    required double price,
    required String startDate,
    required String endDate,
    bool? autoRenew,
  }) async {
    final response = await apiClient.post(
      ApiConstants.subscriptions,
      data: {
        'teacher_id': teacherId,
        'plan_type': planType,
        'sessions_per_month': sessionsPerMonth,
        'price': price,
        'start_date': startDate,
        'end_date': endDate,
        if (autoRenew != null) 'auto_renew': autoRenew,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('No data returned from createSubscription');
    return SubscriptionModel.fromJson(data);
  }

  /// GET /subscriptions
  Future<List<SubscriptionModel>> getSubscriptions() async {
    final response = await apiClient.get(ApiConstants.subscriptions);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /subscriptions/:id
  Future<void> cancelSubscription(String id) async {
    await apiClient.delete(ApiConstants.cancelSubscription(id));
  }
}
