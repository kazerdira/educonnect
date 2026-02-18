import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/features/session/domain/entities/session_series.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';

class SeriesListPage extends StatelessWidget {
  const SeriesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SeriesBloc>()..add(const SeriesListRequested()),
      child: const _SeriesListView(),
    );
  }
}

class _SeriesListView extends StatefulWidget {
  const _SeriesListView();

  @override
  State<_SeriesListView> createState() => _SeriesListViewState();
}

class _SeriesListViewState extends State<_SeriesListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statuses = [null, 'draft', 'active', 'finalized', 'completed'];
  static const _statusLabels = [
    'Toutes',
    'Brouillons',
    'Actives',
    'Finalisées',
    'Terminées',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadSeries();
  }

  void _loadSeries() {
    context.read<SeriesBloc>().add(
          SeriesListRequested(status: _statuses[_tabController.index]),
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
        title: const Text('Mes Séries de Sessions'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'series_list_fab',
        onPressed: () => context.push('/teacher/series/create'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Série'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadSeries(),
        child: BlocBuilder<SeriesBloc, SeriesState>(
          builder: (context, state) {
            if (state is SeriesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SeriesError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                    SizedBox(height: 8.h),
                    Text(state.message, textAlign: TextAlign.center),
                    SizedBox(height: 8.h),
                    ElevatedButton(
                      onPressed: _loadSeries,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            if (state is SeriesListLoaded) {
              if (state.seriesList.isEmpty) {
                return _buildEmptyState(theme);
              }
              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: state.seriesList.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) =>
                    _SeriesCard(series: state.seriesList[index]),
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
            Icons.calendar_view_month_outlined,
            size: 80.sp,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'Aucune série de sessions',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8.h),
          Text(
            'Créez une série pour planifier\nplusieurs sessions avec vos élèves.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.push('/teacher/series/create'),
            icon: const Icon(Icons.add),
            label: const Text('Créer une série'),
          ),
        ],
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final SessionSeries series;
  const _SeriesCard({required this.series});

  bool get _needsAttention =>
      series.pendingCount > 0 ||
      (series.status == 'draft' && series.sessions.isEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/teacher/series/${series.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attention banner
            if (_needsAttention)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                color: Colors.orange.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16.sp, color: Colors.orange[700]),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _getAttentionMessage(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          series.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusChip(status: series.status),
                    ],
                  ),

                  // Subject and Level (if available)
                  if (series.subjectName != null ||
                      series.levelName != null) ...[
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        if (series.subjectName != null)
                          _TagChip(
                            icon: Icons.book_outlined,
                            label: series.subjectName!,
                            color: theme.colorScheme.primary,
                          ),
                        if (series.levelName != null)
                          _TagChip(
                            icon: Icons.school_outlined,
                            label: series.levelName!,
                            color: theme.colorScheme.secondary,
                          ),
                      ],
                    ),
                  ],

                  SizedBox(height: 10.h),

                  // Session type and duration
                  Row(
                    children: [
                      Icon(
                        series.isGroup ? Icons.groups : Icons.person,
                        size: 16.sp,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        series.isGroup ? 'Groupe' : 'Individuel',
                        style: theme.textTheme.bodySmall,
                      ),
                      SizedBox(width: 16.w),
                      Icon(
                        Icons.schedule,
                        size: 16.sp,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${series.durationHours}h/session',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Sessions and enrollment info
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.event,
                        label: '${series.totalSessions} sessions',
                      ),
                      SizedBox(width: 8.w),
                      _InfoChip(
                        icon: Icons.people,
                        label:
                            '${series.enrolledCount}/${series.maxStudents} élèves',
                      ),
                      if (series.pendingCount > 0) ...[
                        SizedBox(width: 8.w),
                        _InfoChip(
                          icon: Icons.hourglass_empty,
                          label: '${series.pendingCount} demande(s)',
                          color: Colors.orange,
                        ),
                      ],
                    ],
                  ),

                  // Star cost info
                  if (series.isFinalized) ...[
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16.sp,
                          color: series.isGroup
                              ? const Color(0xFFFFD600)
                              : const Color(0xFFFFA726),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${series.starCost.toStringAsFixed(0)} DZD / élève',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Next session (if available)
                  if (series.sessions.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.upcoming,
                            size: 16.sp,
                            color: theme.colorScheme.primary,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Prochaine: ${DateFormat('EEE d MMM à HH:mm', 'fr_FR').format(series.sessions.first.startTime)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAttentionMessage() {
    if (series.pendingCount > 0) {
      return '${series.pendingCount} demande(s) d\'inscription en attente';
    } else if (series.status == 'draft' && series.sessions.isEmpty) {
      return 'Ajoutez des sessions pour finaliser';
    }
    return '';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'draft' => ('Brouillon', Colors.grey),
      'active' => ('Active', Colors.blue),
      'finalized' => ('Finalisée', Colors.green),
      'completed' => ('Terminée', Colors.purple),
      'cancelled' => ('Annulée', Colors.red),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TagChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor =
        color ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: chipColor),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: chipColor),
          ),
        ],
      ),
    );
  }
}
