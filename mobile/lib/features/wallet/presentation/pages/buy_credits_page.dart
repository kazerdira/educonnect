import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/wallet/domain/entities/wallet.dart';
import 'package:educonnect/features/wallet/presentation/bloc/wallet_bloc.dart';

class BuyCreditsPage extends StatefulWidget {
  const BuyCreditsPage({super.key});

  @override
  State<BuyCreditsPage> createState() => _BuyCreditsPageState();
}

class _BuyCreditsPageState extends State<BuyCreditsPage> {
  String? _selectedPackageId;
  String _paymentMethod = 'ccp_baridimob';
  final _providerRefController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(WalletPackagesRequested());
  }

  @override
  void dispose() {
    _providerRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acheter des crédits')),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletPurchaseSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Achat soumis avec succès ! En attente de validation par l\'admin.'),
                backgroundColor: AppTheme.success,
              ),
            );
            context.pop();
          }
          if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WalletPackagesLoaded) {
            return _buildContent(state.packages);
          }

          if (state is WalletError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<WalletBloc>()
                        .add(WalletPackagesRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(List<CreditPackage> packages) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Text(
            'Choisissez un forfait',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),

          // ── Package Grid ──
          ...packages.map((pkg) => _PackageCard(
                package: pkg,
                isSelected: _selectedPackageId == pkg.id,
                onTap: () => setState(() => _selectedPackageId = pkg.id),
              )),

          SizedBox(height: 24.h),

          // ── Payment Method ──
          Text(
            'Méthode de paiement',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          _PaymentMethodSelector(
            value: _paymentMethod,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),

          SizedBox(height: 16.h),

          // ── Provider Reference ──
          TextFormField(
            controller: _providerRefController,
            decoration: const InputDecoration(
              labelText: 'Référence de paiement',
              hintText: 'Ex: numéro de reçu BaridiMob',
              prefixIcon: Icon(Icons.receipt_long),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Veuillez entrer la référence du paiement';
              }
              return null;
            },
          ),

          SizedBox(height: 24.h),

          // ── Submit ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedPackageId == null ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              child: const Text('Soumettre l\'achat'),
            ),
          ),

          SizedBox(height: 12.h),
          Text(
            'L\'achat sera validé par un administrateur après vérification du paiement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPackageId == null) return;

    context.read<WalletBloc>().add(WalletBuyCreditsRequested(
          packageId: _selectedPackageId!,
          paymentMethod: _paymentMethod,
          providerRef: _providerRefController.text.trim(),
        ));
  }
}

// ═══════════════════════════════════════════════════════════════
// Package Card
// ═══════════════════════════════════════════════════════════════

class _PackageCard extends StatelessWidget {
  final CreditPackage package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBonus = package.bonus > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.05)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── Radio indicator ──
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primary : const Color(0xFFBDBDBD),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),

            // ── Package info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (hasBonus) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '+${package.bonus.toStringAsFixed(0)} bonus',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${package.groupStars} ⭐ groupe  •  ${package.privateStars} 🌟 privé',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Price ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${package.amount.toStringAsFixed(0)} DZD',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                if (hasBonus)
                  Text(
                    '= ${package.totalCredits.toStringAsFixed(0)} DZD',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Payment Method Selector
// ═══════════════════════════════════════════════════════════════

class _PaymentMethodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PaymentMethodSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _methodTile(
          value: 'ccp_baridimob',
          label: 'CCP / BaridiMob',
          icon: Icons.account_balance,
        ),
        SizedBox(height: 6.h),
        _methodTile(
          value: 'edahabia',
          label: 'Edahabia',
          icon: Icons.credit_card,
        ),
      ],
    );
  }

  Widget _methodTile({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = this.value == value;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.primary)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : const Color(0xFFE0E0E0),
        ),
      ),
      tileColor: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : null,
      onTap: () => onChanged(value),
    );
  }
}
