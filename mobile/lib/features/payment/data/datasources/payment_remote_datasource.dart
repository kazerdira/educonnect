import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/payment/data/models/payment_model.dart';

class PaymentRemoteDataSource {
  final ApiClient apiClient;

  PaymentRemoteDataSource({required this.apiClient});

  /// POST /payments/initiate
  Future<TransactionModel> initiatePayment({
    String? sessionId,
    String? courseId,
    required double amount,
    required String paymentMethod,
    String? description,
  }) async {
    final response = await apiClient.post(
      ApiConstants.initiatePayment,
      data: {
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
    required String transactionRef,
    String? receiptUrl,
  }) async {
    final response = await apiClient.post(
      ApiConstants.confirmPayment,
      data: {
        'transaction_ref': transactionRef,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
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
    double? amount,
    required bool fullRefund,
  }) async {
    final response = await apiClient.post(
      ApiConstants.refundPayment,
      data: {
        'transaction_id': transactionId,
        'reason': reason,
        if (amount != null) 'amount': amount,
        'full_refund': fullRefund,
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
    required double amount,
    required String currency,
    required String paymentMethod,
    required bool autoRenew,
    String? startDate,
  }) async {
    final response = await apiClient.post(
      ApiConstants.subscriptions,
      data: {
        'teacher_id': teacherId,
        'plan_type': planType,
        'amount': amount,
        'currency': currency,
        'payment_method': paymentMethod,
        'auto_renew': autoRenew,
        if (startDate != null) 'start_date': startDate,
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
