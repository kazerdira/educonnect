import 'package:educonnect/features/payment/data/datasources/payment_remote_datasource.dart';
import 'package:educonnect/features/payment/domain/entities/payment.dart';
import 'package:educonnect/features/payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;

  PaymentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Transaction> initiatePayment({
    String? sessionId,
    String? courseId,
    required double amount,
    required String paymentMethod,
    String? description,
  }) =>
      remoteDataSource.initiatePayment(
        sessionId: sessionId,
        courseId: courseId,
        amount: amount,
        paymentMethod: paymentMethod,
        description: description,
      );

  @override
  Future<Transaction> confirmPayment({
    required String transactionRef,
    String? receiptUrl,
  }) =>
      remoteDataSource.confirmPayment(
        transactionRef: transactionRef,
        receiptUrl: receiptUrl,
      );

  @override
  Future<List<Transaction>> getPaymentHistory() =>
      remoteDataSource.getPaymentHistory();

  @override
  Future<Transaction> refundPayment(
    String transactionId, {
    required String reason,
    double? amount,
    required bool fullRefund,
  }) =>
      remoteDataSource.refundPayment(
        transactionId,
        reason: reason,
        amount: amount,
        fullRefund: fullRefund,
      );

  @override
  Future<Subscription> createSubscription({
    required String teacherId,
    required String planType,
    required double amount,
    required String currency,
    required String paymentMethod,
    required bool autoRenew,
    String? startDate,
  }) =>
      remoteDataSource.createSubscription(
        teacherId: teacherId,
        planType: planType,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        autoRenew: autoRenew,
        startDate: startDate,
      );

  @override
  Future<List<Subscription>> getSubscriptions() =>
      remoteDataSource.getSubscriptions();

  @override
  Future<void> cancelSubscription(String id) =>
      remoteDataSource.cancelSubscription(id);
}
