import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/wallet/domain/entities/wallet.dart';
import 'package:educonnect/features/wallet/domain/repositories/wallet_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class WalletEvent extends Equatable {
  const WalletEvent();
  @override
  List<Object?> get props => [];
}

class WalletLoadRequested extends WalletEvent {}

class WalletPackagesRequested extends WalletEvent {}

class WalletTransactionsRequested extends WalletEvent {
  final String? type;
  final int page;

  const WalletTransactionsRequested({this.type, this.page = 1});

  @override
  List<Object?> get props => [type, page];
}

class WalletBuyCreditsRequested extends WalletEvent {
  final String packageId;
  final String paymentMethod;
  final String providerRef;

  const WalletBuyCreditsRequested({
    required this.packageId,
    required this.paymentMethod,
    required this.providerRef,
  });

  @override
  List<Object?> get props => [packageId, paymentMethod, providerRef];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class WalletState extends Equatable {
  const WalletState();
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final Wallet wallet;

  const WalletLoaded({required this.wallet});

  @override
  List<Object?> get props => [wallet];
}

class WalletPackagesLoaded extends WalletState {
  final List<CreditPackage> packages;

  const WalletPackagesLoaded({required this.packages});

  @override
  List<Object?> get props => [packages];
}

class WalletTransactionsLoaded extends WalletState {
  final List<WalletTransaction> transactions;

  const WalletTransactionsLoaded({required this.transactions});

  @override
  List<Object?> get props => [transactions];
}

class WalletPurchaseSuccess extends WalletState {
  final WalletTransaction transaction;

  const WalletPurchaseSuccess({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

class WalletError extends WalletState {
  final String message;

  const WalletError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletRepository walletRepository;

  WalletBloc({required this.walletRepository}) : super(WalletInitial()) {
    on<WalletLoadRequested>(_onLoad);
    on<WalletPackagesRequested>(_onPackages);
    on<WalletTransactionsRequested>(_onTransactions);
    on<WalletBuyCreditsRequested>(_onBuyCredits);
  }

  Future<void> _onLoad(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final wallet = await walletRepository.getWallet();
      emit(WalletLoaded(wallet: wallet));
    } catch (e) {
      emit(WalletError(message: extractApiError(e)));
    }
  }

  Future<void> _onPackages(
    WalletPackagesRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final packages = await walletRepository.getPackages();
      emit(WalletPackagesLoaded(packages: packages));
    } catch (e) {
      emit(WalletError(message: extractApiError(e)));
    }
  }

  Future<void> _onTransactions(
    WalletTransactionsRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final transactions = await walletRepository.getTransactions(
        type: event.type,
        page: event.page,
      );
      emit(WalletTransactionsLoaded(transactions: transactions));
    } catch (e) {
      emit(WalletError(message: extractApiError(e)));
    }
  }

  Future<void> _onBuyCredits(
    WalletBuyCreditsRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final tx = await walletRepository.buyCredits(
        packageId: event.packageId,
        paymentMethod: event.paymentMethod,
        providerRef: event.providerRef,
      );
      emit(WalletPurchaseSuccess(transaction: tx));
    } catch (e) {
      emit(WalletError(message: extractApiError(e)));
    }
  }
}
