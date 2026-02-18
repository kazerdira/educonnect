import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/wallet/domain/entities/wallet.dart';
import 'package:educonnect/features/wallet/presentation/bloc/wallet_bloc.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Portefeuille')),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletPurchaseSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Achat soumis ! En attente de validation.'),
                backgroundColor: AppTheme.success,
              ),
            );
            // Reload wallet after purchase
            context.read<WalletBloc>().add(WalletLoadRequested());
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WalletError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<WalletBloc>().add(WalletLoadRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is WalletLoaded) {
            return _buildWalletContent(state.wallet, theme);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildWalletContent(Wallet wallet, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<WalletBloc>().add(WalletLoadRequested());
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // ── Balance Card ──
          _BalanceCard(wallet: wallet),
          SizedBox(height: 20.h),

          // ── Star Summary ──
          _StarSummaryRow(wallet: wallet),
          SizedBox(height: 20.h),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/wallet/buy'),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Acheter des crédits'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/wallet/transactions'),
                  icon: const Icon(Icons.history),
                  label: const Text('Historique'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // ── Stats Row ──
          _StatsRow(wallet: wallet, theme: theme),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Balance Card
// ═══════════════════════════════════════════════════════════════

class _BalanceCard extends StatelessWidget {
  final Wallet wallet;

  const _BalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solde disponible',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${wallet.balance.toStringAsFixed(0)} DZD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Star Summary
// ═══════════════════════════════════════════════════════════════

class _StarSummaryRow extends StatelessWidget {
  final Wallet wallet;

  const _StarSummaryRow({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StarCard(
            icon: Icons.star,
            iconColor: const Color(0xFFFFD600), // Yellow star
            label: 'Étoiles Groupe',
            count: wallet.groupStarsAvailable,
            subtitle: '50 DZD / étoile',
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _StarCard(
            icon: Icons.star,
            iconColor: AppTheme.accent, // Orange star
            label: 'Étoiles Privé',
            count: wallet.privateStarsAvailable,
            subtitle: '70 DZD / étoile',
          ),
        ),
      ],
    );
  }
}

class _StarCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final String subtitle;

  const _StarCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32.sp),
          SizedBox(height: 8.h),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Stats Row
// ═══════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final Wallet wallet;
  final ThemeData theme;

  const _StatsRow({required this.wallet, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Résumé',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        _StatTile(
          icon: Icons.arrow_downward,
          color: AppTheme.success,
          label: 'Total acheté',
          value: '${wallet.totalPurchased.toStringAsFixed(0)} DZD',
        ),
        SizedBox(height: 8.h),
        _StatTile(
          icon: Icons.arrow_upward,
          color: AppTheme.error,
          label: 'Total dépensé',
          value: '${wallet.totalSpent.toStringAsFixed(0)} DZD',
        ),
        SizedBox(height: 8.h),
        _StatTile(
          icon: Icons.replay,
          color: AppTheme.primaryLight,
          label: 'Total remboursé',
          value: '${wallet.totalRefunded.toStringAsFixed(0)} DZD',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
