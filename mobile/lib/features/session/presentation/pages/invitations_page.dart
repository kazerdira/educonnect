import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/features/session/domain/entities/enrollment.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';

class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SeriesBloc>()..add(const InvitationsListRequested()),
      child: const _InvitationsView(),
    );
  }
}

class _InvitationsView extends StatefulWidget {
  const _InvitationsView();

  @override
  State<_InvitationsView> createState() => _InvitationsViewState();
}

class _InvitationsViewState extends State<_InvitationsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statuses = [null, 'invited', 'accepted', 'declined'];
  static const _statusLabels = [
    'Toutes',
    'En attente',
    'Acceptées',
    'Refusées'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadInvitations();
  }

  void _loadInvitations() {
    context.read<SeriesBloc>().add(
          InvitationsListRequested(status: _statuses[_tabController.index]),
        );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Invitations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _statusLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadInvitations(),
        child: BlocConsumer<SeriesBloc, SeriesState>(
          listener: (context, state) {
            if (state is InvitationAccepted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invitation acceptée!'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadInvitations();
            } else if (state is InvitationDeclined) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invitation refusée'),
                  backgroundColor: Colors.orange,
                ),
              );
              _loadInvitations();
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

            if (state is SeriesError && state is! InvitationsLoaded) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                    SizedBox(height: 8.h),
                    Text(state.message, textAlign: TextAlign.center),
                    SizedBox(height: 8.h),
                    ElevatedButton(
                      onPressed: _loadInvitations,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            if (state is InvitationsLoaded) {
              if (state.invitations.isEmpty) {
                return _buildEmptyState(theme);
              }
              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: state.invitations.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) =>
                    _InvitationCard(invitation: state.invitations[index]),
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
            Icons.mail_outline,
            size: 80.sp,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'Aucune invitation',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8.h),
          Text(
            'Vous recevrez une notification\nlorsqu\'un enseignant vous invitera.',
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

class _InvitationCard extends StatelessWidget {
  final Enrollment invitation;
  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy', 'fr_FR');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16.w),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    invitation.teacherName?.isNotEmpty == true
                        ? invitation.teacherName![0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.teacherName ?? 'Enseignant',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'Vous invite à rejoindre',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: invitation.status),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.seriesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16.sp,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Reçue le ${dateFormat.format(invitation.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),

                // Actions for pending invitations
                if (invitation.isInvitation) ...[
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _showDeclineDialog(context, invitation),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Refuser'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            context.read<SeriesBloc>().add(
                                  AcceptInvitationRequested(
                                    enrollmentId: invitation.id,
                                  ),
                                );
                          },
                          child: const Text('Accepter'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Show acceptance date
                if (invitation.isAccepted && invitation.acceptedAt != null) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16.sp,
                        color: Colors.green,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Acceptée le ${dateFormat.format(invitation.acceptedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],

                // Show decline reason
                if (invitation.isDeclined &&
                    invitation.declineReason != null) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Motif: ${invitation.declineReason}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog(BuildContext context, Enrollment invitation) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refuser l\'invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voulez-vous vraiment refuser cette invitation?'),
            SizedBox(height: 16.h),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif (optionnel)',
                hintText: 'Pourquoi refusez-vous?',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SeriesBloc>().add(
                    DeclineInvitationRequested(
                      enrollmentId: invitation.id,
                      reason: reasonController.text.trim().isEmpty
                          ? null
                          : reasonController.text.trim(),
                    ),
                  );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Refuser'),
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
      'invited' => ('En attente', Colors.orange),
      'accepted' => ('Acceptée', Colors.green),
      'declined' => ('Refusée', Colors.red),
      'requested' => ('Demandée', Colors.blue),
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
