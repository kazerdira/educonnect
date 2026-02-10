import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/payment/domain/entities/payment.dart';
import 'package:educonnect/features/payment/domain/repositories/payment_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();
  @override
  List<Object?> get props => [];
}

class PaymentHistoryRequested extends PaymentEvent {}

class InitiatePaymentRequested extends PaymentEvent {
  final String? sessionId;
  final String? courseId;
  final double amount;
  final String paymentMethod;
  final String? description;

  const InitiatePaymentRequested({
    this.sessionId,
    this.courseId,
    required this.amount,
    required this.paymentMethod,
    this.description,
  });

  @override
  List<Object?> get props => [sessionId, courseId, amount, paymentMethod];
}

class ConfirmPaymentRequested extends PaymentEvent {
  final String transactionRef;
  final String? receiptUrl;

  const ConfirmPaymentRequested({
    required this.transactionRef,
    this.receiptUrl,
  });

  @override
  List<Object?> get props => [transactionRef];
}

class RefundPaymentRequested extends PaymentEvent {
  final String transactionId;
  final String reason;
  final double? amount;
  final bool fullRefund;

  const RefundPaymentRequested({
    required this.transactionId,
    required this.reason,
    this.amount,
    required this.fullRefund,
  });

  @override
  List<Object?> get props => [transactionId, reason, fullRefund];
}

class SubscriptionsRequested extends PaymentEvent {}

class CreateSubscriptionRequested extends PaymentEvent {
  final String teacherId;
  final String planType;
  final double amount;
  final String currency;
  final String paymentMethod;
  final bool autoRenew;
  final String? startDate;

  const CreateSubscriptionRequested({
    required this.teacherId,
    required this.planType,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.autoRenew,
    this.startDate,
  });

  @override
  List<Object?> get props => [teacherId, planType, amount];
}

class CancelSubscriptionRequested extends PaymentEvent {
  final String subscriptionId;
  const CancelSubscriptionRequested({required this.subscriptionId});
  @override
  List<Object?> get props => [subscriptionId];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class PaymentState extends Equatable {
  const PaymentState();
  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentHistoryLoaded extends PaymentState {
  final List<Transaction> transactions;
  const PaymentHistoryLoaded({required this.transactions});
  @override
  List<Object?> get props => [transactions];
}

class PaymentInitiated extends PaymentState {
  final Transaction transaction;
  const PaymentInitiated({required this.transaction});
  @override
  List<Object?> get props => [transaction];
}

class PaymentConfirmed extends PaymentState {
  final Transaction transaction;
  const PaymentConfirmed({required this.transaction});
  @override
  List<Object?> get props => [transaction];
}

class PaymentRefunded extends PaymentState {
  final Transaction transaction;
  const PaymentRefunded({required this.transaction});
  @override
  List<Object?> get props => [transaction];
}

class SubscriptionsLoaded extends PaymentState {
  final List<Subscription> subscriptions;
  const SubscriptionsLoaded({required this.subscriptions});
  @override
  List<Object?> get props => [subscriptions];
}

class SubscriptionCreated extends PaymentState {
  final Subscription subscription;
  const SubscriptionCreated({required this.subscription});
  @override
  List<Object?> get props => [subscription];
}

class SubscriptionCancelled extends PaymentState {}

class PaymentError extends PaymentState {
  final String message;
  const PaymentError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository paymentRepository;

  PaymentBloc({required this.paymentRepository}) : super(PaymentInitial()) {
    on<PaymentHistoryRequested>(_onPaymentHistory);
    on<InitiatePaymentRequested>(_onInitiatePayment);
    on<ConfirmPaymentRequested>(_onConfirmPayment);
    on<RefundPaymentRequested>(_onRefundPayment);
    on<SubscriptionsRequested>(_onSubscriptions);
    on<CreateSubscriptionRequested>(_onCreateSubscription);
    on<CancelSubscriptionRequested>(_onCancelSubscription);
  }

  Future<void> _onPaymentHistory(
    PaymentHistoryRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final transactions = await paymentRepository.getPaymentHistory();
      emit(PaymentHistoryLoaded(transactions: transactions));
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  Future<void> _onInitiatePayment(
    InitiatePaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final transaction = await paymentRepository.initiatePayment(
        sessionId: event.sessionId,
        courseId: event.courseId,
        amount: event.amount,
        paymentMethod: event.paymentMethod,
        description: event.description,
      );
      emit(PaymentInitiated(transaction: transaction));
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  Future<void> _onConfirmPayment(
    ConfirmPaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final transaction = await paymentRepository.confirmPayment(
        transactionRef: event.transactionRef,
        receiptUrl: event.receiptUrl,
      );
      emit(PaymentConfirmed(transaction: transaction));
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  Future<void> _onRefundPayment(
    RefundPaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final transaction = await paymentRepository.refundPayment(
        event.transactionId,
        reason: event.reason,
        amount: event.amount,
        fullRefund: event.fullRefund,
      );
      emit(PaymentRefunded(transaction: transaction));
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  Future<void> _onSubscriptions(
    SubscriptionsRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final subscriptions = await paymentRepository.getSubscriptions();
      emit(SubscriptionsLoaded(subscriptions: subscriptions));
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateSubscription(
    CreateSubscriptionRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final subscription = await paymentRepository.createSubscription(
        teacherId: event.teacherId,
        planType: event.planType,
        amount: event.amount,
        currency: event.currency,
        paymentMethod: event.paymentMethod,
        autoRenew: event.autoRenew,
        startDate: event.startDate,
      );
      emit(SubscriptionCreated(subscription: subscription));
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  Future<void> _onCancelSubscription(
    CancelSubscriptionRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      await paymentRepository.cancelSubscription(event.subscriptionId);
      emit(SubscriptionCancelled());
    } catch (e) {
      emit(PaymentError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['error']?.toString() ??
          e.message ??
          'Erreur inconnue';
    }
    return e.toString();
  }
}
