import 'package:educonnect/features/payment/domain/entities/payment.dart';

abstract class PaymentRepository {
  Future<Transaction> initiatePayment({
    String? sessionId,
    String? courseId,
    required double amount,
    required String paymentMethod,
    String? description,
  });

  Future<Transaction> confirmPayment({
    required String transactionRef,
    String? receiptUrl,
  });

  Future<List<Transaction>> getPaymentHistory();

  Future<Transaction> refundPayment(
    String transactionId, {
    required String reason,
    double? amount,
    required bool fullRefund,
  });

  Future<Subscription> createSubscription({
    required String teacherId,
    required String planType,
    required double amount,
    required String currency,
    required String paymentMethod,
    required bool autoRenew,
    String? startDate,
  });

  Future<List<Subscription>> getSubscriptions();

  Future<void> cancelSubscription(String id);
}
