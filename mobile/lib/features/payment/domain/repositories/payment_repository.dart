import 'package:educonnect/features/payment/domain/entities/payment.dart';

abstract class PaymentRepository {
  Future<Transaction> initiatePayment({
    required String payeeId,
    String? sessionId,
    String? courseId,
    required double amount,
    required String paymentMethod,
    String? description,
  });

  Future<Transaction> confirmPayment({
    required String transactionId,
    required String providerReference,
  });

  Future<List<Transaction>> getPaymentHistory();

  Future<Transaction> refundPayment(
    String transactionId, {
    required String reason,
    required double amount,
  });

  Future<Subscription> createSubscription({
    required String teacherId,
    required String planType,
    required int sessionsPerMonth,
    required double price,
    required String startDate,
    required String endDate,
    bool? autoRenew,
  });

  Future<List<Subscription>> getSubscriptions();

  Future<void> cancelSubscription(String id);
}
