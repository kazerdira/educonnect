import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/features/session/domain/entities/platform_fee.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';

class PlatformFeesPage extends StatelessWidget {
  const PlatformFeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SeriesBloc>()..add(const PendingFeesRequested()),
      child: const _PlatformFeesView(),
    );
  }
}

class _PlatformFeesView extends StatelessWidget {
  const _PlatformFeesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frais de plateforme'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<SeriesBloc>().add(const PendingFeesRequested());
        },
        child: BlocConsumer<SeriesBloc, SeriesState>(
          listener: (context, state) {
            if (state is FeePaymentConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Paiement confirmé! En attente de vérification.'),
                  backgroundColor: Colors.green,
                ),
              );
              context.read<SeriesBloc>().add(const PendingFeesRequested());
            } else if (state is SeriesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is SeriesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SeriesError && state is! PendingFeesLoaded) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                    SizedBox(height: 8.h),
                    Text(state.message, textAlign: TextAlign.center),
                    SizedBox(height: 8.h),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<SeriesBloc>()
                            .add(const PendingFeesRequested());
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            if (state is PendingFeesLoaded) {
              if (state.fees.isEmpty) {
                return _buildEmptyState(theme);
              }

              final totalPending = state.fees
                  .where((f) => f.isPending)
                  .fold<double>(0, (sum, f) => sum + f.amount);

              return ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  // Summary card
                  if (totalPending > 0) ...[
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pending_actions,
                              size: 40.sp,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total à payer',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                  Text(
                                    '${totalPending.toStringAsFixed(0)} DA',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Payment methods info
                  _PaymentMethodsCard(),
                  SizedBox(height: 24.h),

                  // Fees list
                  Text(
                    'Frais en attente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ...state.fees.map((fee) => _FeeCard(fee: fee)),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80.sp,
            color: Colors.green.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'Aucun frais en attente',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8.h),
          Text(
            'Vous n\'avez pas de frais de plateforme à payer.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Méthodes de paiement',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _PaymentMethod(
              icon: Icons.phone_android,
              title: 'BaridiMob',
              subtitle: 'Transfert vers: 00799999XXXXXXXXXX12',
            ),
            SizedBox(height: 8.h),
            _PaymentMethod(
              icon: Icons.account_balance,
              title: 'CCP',
              subtitle: 'N° compte: XXXX XXXX XXX XX',
            ),
            SizedBox(height: 8.h),
            _PaymentMethod(
              icon: Icons.credit_card,
              title: 'Carte EDAHABIA',
              subtitle: 'Disponible via le portail CIB',
            ),
            SizedBox(height: 12.h),
            Text(
              '⚠️ Après paiement, entrez la référence de la transaction pour confirmation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer
                    .withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PaymentMethod({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 20.sp,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer
                      .withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeeCard extends StatelessWidget {
  final PlatformFee fee;
  const _FeeCard({required this.fee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy', 'fr_FR');

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    fee.seriesTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: fee.status),
              ],
            ),
            SizedBox(height: 12.h),

            // Details
            Row(
              children: [
                _DetailItem(
                  icon: Icons.people,
                  value: '${fee.enrolledCount}',
                  label: 'élèves',
                ),
                _DetailItem(
                  icon: Icons.event,
                  value: '${fee.totalSessions}',
                  label: 'sessions',
                ),
                _DetailItem(
                  icon: Icons.schedule,
                  value: '${(fee.durationHours * fee.totalSessions).toStringAsFixed(1)}h',
                  label: 'total',
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Fee breakdown
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détail: ${fee.enrolledCount} élèves × ${fee.totalSessions} sessions × ${fee.durationHours}h × ${fee.feeRate} DA',
                    style: theme.textTheme.bodySmall,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Montant total:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${fee.amount.toStringAsFixed(0)} ${PlatformFee.currency}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Creation date
            SizedBox(height: 8.h),
            Text(
              'Créé le ${dateFormat.format(fee.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),

            // Actions for pending fees
            if (fee.isPending) ...[
              SizedBox(height: 16.h),
              FilledButton.icon(
                onPressed: () => _showPaymentDialog(context, fee),
                icon: const Icon(Icons.payment),
                label: const Text('Confirmer le paiement'),
              ),
            ],

            // Show payment info for paid fees
            if (fee.isPaid || fee.isVerified) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          fee.isVerified ? Icons.verified : Icons.pending,
                          color: fee.isVerified ? Colors.green : Colors.orange,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          fee.isVerified
                              ? 'Paiement vérifié'
                              : 'En attente de vérification',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                fee.isVerified ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (fee.providerRef != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Référence: ${fee.providerRef}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (fee.paidAt != null) ...[
                      Text(
                        'Payé le: ${dateFormat.format(fee.paidAt!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, PlatformFee fee) {
    final methodController = TextEditingController();
    final referenceController = TextEditingController();
    String selectedMethod = 'baridimob';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SeriesBloc>(),
        child: StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);

            return Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 16.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Confirmer le paiement',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Montant: ${fee.amount.toStringAsFixed(0)} ${PlatformFee.currency}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Payment method selection
                  Text(
                    'Méthode de paiement',
                    style: theme.textTheme.titleSmall,
                  ),
                  SizedBox(height: 8.h),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'baridimob',
                        label: Text('BaridiMob'),
                        icon: Icon(Icons.phone_android),
                      ),
                      ButtonSegment(
                        value: 'ccp',
                        label: Text('CCP'),
                        icon: Icon(Icons.account_balance),
                      ),
                      ButtonSegment(
                        value: 'edahabia',
                        label: Text('EDAHABIA'),
                        icon: Icon(Icons.credit_card),
                      ),
                    ],
                    selected: {selectedMethod},
                    onSelectionChanged: (value) {
                      setState(() => selectedMethod = value.first);
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Payment reference
                  TextField(
                    controller: referenceController,
                    decoration: InputDecoration(
                      labelText: 'Référence de paiement *',
                      hintText: 'Entrez la référence de la transaction...',
                      prefixIcon: const Icon(Icons.receipt),
                      helperText:
                          'Numéro de transaction ou référence de paiement',
                    ),
                  ),
                  SizedBox(height: 24.h),

                  FilledButton(
                    onPressed: () {
                      if (referenceController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Veuillez entrer la référence de paiement'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      context.read<SeriesBloc>().add(
                            ConfirmFeePaymentRequested(
                              feeId: fee.id,
                              providerRef: referenceController.text.trim(),
                            ),
                          );

                      Navigator.pop(context);
                    },
                    child: const Text('Confirmer le paiement'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DetailItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: theme.colorScheme.primary),
          SizedBox(width: 4.w),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 2.w),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('En attente', Colors.orange),
      'paid' => ('Payé', Colors.blue),
      'verified' => ('Vérifié', Colors.green),
      'refunded' => ('Remboursé', Colors.purple),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
