import 'package:educonnect/features/payment/data/datasources/payment_remote_datasource.dart';
import 'package:educonnect/features/payment/domain/entities/payment.dart';
import 'package:educonnect/features/payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;

  PaymentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Transaction> initiatePayment({
    required String payeeId,
    String? sessionId,
    String? courseId,
    required double amount,
    required String paymentMethod,
    String? description,
  }) =>
      remoteDataSource.initiatePayment(
        payeeId: payeeId,
        sessionId: sessionId,
        courseId: courseId,
        amount: amount,
        paymentMethod: paymentMethod,
        description: description,
      );

  @override
  Future<Transaction> confirmPayment({
    required String transactionId,
    required String providerReference,
  }) =>
      remoteDataSource.confirmPayment(
        transactionId: transactionId,
        providerReference: providerReference,
      );

  @override
  Future<List<Transaction>> getPaymentHistory() =>
      remoteDataSource.getPaymentHistory();

  @override
  Future<Transaction> refundPayment(
    String transactionId, {
    required String reason,
    required double amount,
  }) =>
      remoteDataSource.refundPayment(
        transactionId,
        reason: reason,
        amount: amount,
      );

  @override
  Future<Subscription> createSubscription({
    required String teacherId,
    required String planType,
    required int sessionsPerMonth,
    required double price,
    required String startDate,
    required String endDate,
    bool? autoRenew,
  }) =>
      remoteDataSource.createSubscription(
        teacherId: teacherId,
        planType: planType,
        sessionsPerMonth: sessionsPerMonth,
        price: price,
        startDate: startDate,
        endDate: endDate,
        autoRenew: autoRenew,
      );

  @override
  Future<List<Subscription>> getSubscriptions() =>
      remoteDataSource.getSubscriptions();

  @override
  Future<void> cancelSubscription(String id) =>
      remoteDataSource.cancelSubscription(id);
}
