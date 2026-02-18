import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/core/constants/levels.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';
import 'package:educonnect/features/session/domain/entities/session_series.dart';

// ────────────────────────────────────────────────────────────────────────────
// Browse Series Page — professional student explorer with sliver-based layout
// ────────────────────────────────────────────────────────────────────────────

class BrowseSeriesPage extends StatefulWidget {
  const BrowseSeriesPage({super.key});

  @override
  State<BrowseSeriesPage> createState() => _BrowseSeriesPageState();
}

class _SubjectItem {
  final String id;
  final String name;
  const _SubjectItem({required this.id, required this.name});
}

class _BrowseSeriesPageState extends State<BrowseSeriesPage> {
  String? _selectedLevel;
  String? _selectedSessionType;
  String? _selectedSubject;
  List<_SubjectItem> _subjects = [];

  // ── Lifecycle ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ensureLevelsLoaded();
    _fetchSubjects();
    _loadSeries();
  }

  Future<void> _ensureLevelsLoaded() async {
    if (Levels.isLoaded) return;
    try {
      final api = getIt<ApiClient>();
      await Levels.load(api);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fetchSubjects() async {
    try {
      final api = getIt<ApiClient>();
      final response = await api.dio.get(ApiConstants.subjects);
      final data = response.data['data'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _subjects = data
            .map((e) => _SubjectItem(
                  id: e['id'] as String? ?? '',
                  name: e['name_fr'] as String? ?? e['name'] as String? ?? '',
                ))
            .toList();
      });
    } catch (_) {}
  }

  void _loadSeries() {
    context.read<SeriesBloc>().add(BrowseSeriesRequested(
          subjectId: _selectedSubject,
          levelId: _selectedLevel,
          sessionType: _selectedSessionType,
        ));
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorer'),
        centerTitle: false,
        actions: [
          _filterBadgeButton(cs),
        ],
      ),
      body: BlocListener<SeriesBloc, SeriesState>(
        listener: (context, state) {
          if (state is JoinRequestSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Demande envoyée avec succès !'),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            );
            _loadSeries();
          }
        },
        child: BlocBuilder<SeriesBloc, SeriesState>(
          buildWhen: (prev, curr) =>
              curr is SeriesLoading ||
              curr is SeriesListLoaded ||
              curr is SeriesError,
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () async => _loadSeries(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Subject chips ─────────────────────────
                  if (_subjects.isNotEmpty)
                    SliverToBoxAdapter(child: _buildSubjectChips(cs)),

                  // ── Active filter badges ──────────────────
                  if (_hasActiveFilters)
                    SliverToBoxAdapter(child: _buildActiveFilters(cs)),

                  // ── Content (loading / error / list / empty)
                  ..._buildContent(state, theme),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedLevel != null ||
      _selectedSessionType != null ||
      _selectedSubject != null;

  // ── Filter badge on AppBar ─────────────────────────────────────

  Widget _filterBadgeButton(ColorScheme cs) {
    final filterCount = [
      _selectedLevel,
      _selectedSessionType,
    ].where((e) => e != null).length;

    return Padding(
      padding: EdgeInsets.only(right: 4.w),
      child: IconButton(
        icon: Badge(
          isLabelVisible: filterCount > 0,
          label: Text('$filterCount'),
          backgroundColor: cs.primary,
          child: const Icon(Icons.tune_rounded),
        ),
        onPressed: _showFilters,
        tooltip: 'Filtres avancés',
      ),
    );
  }

  // ── Subject Chips Row ──────────────────────────────────────────

  Widget _buildSubjectChips(ColorScheme cs) {
    return SizedBox(
      height: 48.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        itemCount: _subjects.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final subj = _subjects[index];
          final isSelected = _selectedSubject == subj.id;
          return FilterChip(
            selected: isSelected,
            label: Text(subj.name),
            labelStyle: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
            ),
            onSelected: (selected) {
              setState(() => _selectedSubject = selected ? subj.id : null);
              _loadSeries();
            },
            selectedColor: cs.primaryContainer,
            backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
            checkmarkColor: cs.primary,
            showCheckmark: true,
            side: isSelected
                ? BorderSide(color: cs.primary.withOpacity(0.3))
                : BorderSide.none,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }

  // ── Active Filter Badges ───────────────────────────────────────

  Widget _buildActiveFilters(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 4.h,
        children: [
          if (_selectedSubject != null)
            _filterChipTag(
              icon: Icons.menu_book_rounded,
              label: _subjects
                      .where((s) => s.id == _selectedSubject)
                      .map((s) => s.name)
                      .firstOrNull ??
                  'Matière',
              color: Colors.teal,
              onRemove: () {
                setState(() => _selectedSubject = null);
                _loadSeries();
              },
            ),
          if (_selectedLevel != null)
            _filterChipTag(
              icon: Icons.school_rounded,
              label: Levels.all
                      .where((l) => l.code == _selectedLevel)
                      .map((l) => l.name)
                      .firstOrNull ??
                  _selectedLevel!,
              color: Colors.indigo,
              onRemove: () {
                setState(() => _selectedLevel = null);
                _loadSeries();
              },
            ),
          if (_selectedSessionType != null)
            _filterChipTag(
              icon: _selectedSessionType == 'group'
                  ? Icons.groups_rounded
                  : Icons.person_rounded,
              label: _selectedSessionType == 'group'
                  ? 'Groupe'
                  : 'Individuel',
              color: Colors.deepPurple,
              onRemove: () {
                setState(() => _selectedSessionType = null);
                _loadSeries();
              },
            ),
        ],
      ),
    );
  }

  Widget _filterChipTag({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Chip(
      avatar: Icon(icon, size: 15.sp, color: color),
      label: Text(label,
          style: TextStyle(
              fontSize: 11.sp, color: color, fontWeight: FontWeight.w500)),
      deleteIcon: Icon(Icons.close_rounded, size: 15.sp, color: color),
      onDeleted: onRemove,
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
    );
  }

  // ── Main Content (slivers) ─────────────────────────────────────

  List<Widget> _buildContent(SeriesState state, ThemeData theme) {
    if (state is SeriesLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Chargement des séries…',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (state is SeriesError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 56.sp, color: Colors.grey[400]),
                  SizedBox(height: 16.h),
                  Text(
                    'Impossible de charger les séries',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    state.message,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  FilledButton.icon(
                    onPressed: _loadSeries,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (state is SeriesListLoaded) {
      final series = state.seriesList;

      if (series.isEmpty) {
        return [
          SliverFillRemaining(hasScrollBody: false, child: _emptyState()),
        ];
      }

      return [
        // Result count
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
            child: Text(
              '${series.length} cours disponible${series.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        // Cards
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _seriesCard(theme, series[index]),
              ),
              childCount: series.length,
            ),
          ),
        ),
      ];
    }

    // Initial / unknown state
    return [
      SliverFillRemaining(hasScrollBody: false, child: _emptyState()),
    ];
  }

  // ── Empty State ────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 40.sp, color: Colors.grey[400]),
            ),
            SizedBox(height: 20.h),
            Text(
              'Aucune série trouvée',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _hasActiveFilters
                  ? 'Essayez de modifier ou supprimer vos filtres'
                  : 'Aucune série disponible pour le moment',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              SizedBox(height: 20.h),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedLevel = null;
                    _selectedSessionType = null;
                    _selectedSubject = null;
                  });
                  _loadSeries();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Supprimer les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Series Card ────────────────────────────────────────────────

  Widget _seriesCard(ThemeData theme, SessionSeries series) {
    final cs = theme.colorScheme;
    final nextSession =
        series.sessions.isNotEmpty ? series.sessions.first : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => context.push('/series/${series.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Subject · Level ────────────────────────
                  if (series.subjectName != null ||
                      series.levelName != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Text(
                        [
                          if (series.subjectName?.isNotEmpty == true)
                            series.subjectName,
                          if (series.levelName?.isNotEmpty == true)
                            series.levelName,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // ── Title ──────────────────────────────────
                  Text(
                    series.title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10.h),

                  // ── Teacher ────────────────────────────────
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12.r,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          series.teacherName.isNotEmpty
                              ? series.teacherName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          series.teacherName,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  // ── Schedule info ──────────────────────────
                  if (nextSession != null)
                    _scheduleRow(
                      Icons.event_rounded,
                      'Prochaine séance : ${_formatNextDate(nextSession.startTime)}',
                      highlight: true,
                    ),
                  _scheduleRow(
                    Icons.schedule_rounded,
                    '${series.totalSessions} séance${series.totalSessions > 1 ? 's' : ''} · ${_formatDuration(series.durationHours)} chacune',
                  ),
                  if (series.isGroup)
                    _scheduleRow(
                      Icons.people_outline_rounded,
                      _spotsText(series),
                    )
                  else
                    _scheduleRow(
                      Icons.person_outline_rounded,
                      'Cours particulier',
                    ),
                  SizedBox(height: 14.h),

                  // ── Price + Action ─────────────────────────
                  Row(
                    children: [
                      Text(
                        '${series.pricePerHour.toStringAsFixed(0)} DA',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        ' /h',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      _buildActionButton(series, cs),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(IconData icon, String text, {bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Icon(icon,
              size: 15.sp,
              color: highlight ? Colors.orange[700] : Colors.grey[500]),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: highlight ? Colors.orange[800] : Colors.grey[700],
                fontWeight: highlight ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _spotsText(SessionSeries series) {
    final remaining = series.maxStudents - series.enrolledCount;
    if (remaining <= 0) return 'Complet';
    if (remaining <= 2) {
      return 'Plus que $remaining place${remaining > 1 ? 's' : ''} !';
    }
    return '$remaining places disponibles';
  }

  String _formatDuration(double hours) {
    if (hours == hours.roundToDouble()) return '${hours.toInt()}h';
    final h = hours.toInt();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}min';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _formatNextDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Demain';
    return DateFormat('d MMM', 'fr').format(dt);
  }

  // ── Action Button ──────────────────────────────────────────────

  Widget _buildActionButton(SessionSeries series, ColorScheme cs) {
    if (series.isEnrolled) {
      return FilledButton.tonalIcon(
        icon: Icon(Icons.check_circle_rounded, size: 16.sp),
        label: Text('Inscrit', style: TextStyle(fontSize: 12.sp)),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green[50],
          foregroundColor: Colors.green[700],
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
        onPressed: () => context.push('/series/${series.id}'),
      );
    }

    if (series.hasPendingRequest) {
      return OutlinedButton.icon(
        icon: Icon(Icons.hourglass_top_rounded, size: 16.sp),
        label: Text('En attente', style: TextStyle(fontSize: 12.sp)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange[700],
          side: BorderSide(color: Colors.orange[300]!),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
        onPressed: null,
      );
    }

    if (series.hasInvitation) {
      return FilledButton.icon(
        icon: Icon(Icons.mail_rounded, size: 16.sp),
        label: Text('Invitation', style: TextStyle(fontSize: 12.sp)),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue[600],
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
        onPressed: () => context.push('/student/invitations'),
      );
    }

    if (series.isDeclined) {
      return OutlinedButton.icon(
        icon: Icon(Icons.refresh_rounded, size: 16.sp),
        label: Text('Redemander', style: TextStyle(fontSize: 12.sp)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[600],
          side: BorderSide(color: Colors.grey[400]!),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
        onPressed: () => _requestToJoin(series),
      );
    }

    return FilledButton.icon(
      icon: Icon(Icons.send_rounded, size: 16.sp),
      label: Text('Demander', style: TextStyle(fontSize: 12.sp)),
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
      onPressed: () => _requestToJoin(series),
    );
  }

  // ── Join Dialog ────────────────────────────────────────────────

  void _requestToJoin(SessionSeries series) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Demander à rejoindre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogInfoRow(Icons.class_rounded, series.title),
            SizedBox(height: 8.h),
            _dialogInfoRow(Icons.person_rounded, series.teacherName),
            SizedBox(height: 8.h),
            _dialogInfoRow(Icons.payments_rounded,
                '${series.pricePerHour.toStringAsFixed(0)} DA/heure'),
            SizedBox(height: 16.h),
            Text(
              'Voulez-vous envoyer une demande pour rejoindre cette série ?',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SeriesBloc>().add(
                    RequestToJoinSeriesRequested(seriesId: series.id),
                  );
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Widget _dialogInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: Colors.grey[600]),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 14.sp),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FILTERS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════

  void _showFilters() {
    String? tempLevel = _selectedLevel;
    String? tempSessionType = _selectedSessionType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              margin: EdgeInsets.all(12.w),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.h,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filtres',
                              style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold)),
                          if (tempLevel != null || tempSessionType != null)
                            TextButton(
                              onPressed: () => setSheetState(() {
                                tempLevel = null;
                                tempSessionType = null;
                              }),
                              child: const Text('Réinitialiser'),
                            ),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      // ── Level picker ───────────────────────
                      Text('Niveau scolaire',
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8.h),
                      InkWell(
                        onTap: () => _showLevelPicker(
                          ctx,
                          tempLevel,
                          (v) => setSheetState(() => tempLevel = v),
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                            prefixIcon: const Icon(Icons.school_outlined),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 14.h),
                          ),
                          child: Text(
                            tempLevel != null
                                ? Levels.all
                                        .where((l) => l.code == tempLevel)
                                        .map((l) => l.name)
                                        .firstOrNull ??
                                    'Niveau sélectionné'
                                : 'Tous les niveaux',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color:
                                  tempLevel != null ? null : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // ── Session type toggle cards ──────────
                      Text('Type de session',
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          _sessionTypeOption(
                            label: 'Tous',
                            icon: Icons.apps_rounded,
                            isSelected: tempSessionType == null,
                            onTap: () =>
                                setSheetState(() => tempSessionType = null),
                          ),
                          SizedBox(width: 8.w),
                          _sessionTypeOption(
                            label: 'Individuel',
                            icon: Icons.person_rounded,
                            isSelected: tempSessionType == 'one_on_one',
                            onTap: () => setSheetState(
                                () => tempSessionType = 'one_on_one'),
                          ),
                          SizedBox(width: 8.w),
                          _sessionTypeOption(
                            label: 'Groupe',
                            icon: Icons.groups_rounded,
                            isSelected: tempSessionType == 'group',
                            onTap: () => setSheetState(
                                () => tempSessionType = 'group'),
                          ),
                        ],
                      ),
                      SizedBox(height: 28.h),

                      // ── Apply ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Appliquer les filtres'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedLevel = tempLevel;
                              _selectedSessionType = tempSessionType;
                            });
                            Navigator.pop(ctx);
                            _loadSeries();
                          },
                        ),
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sessionTypeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primaryContainer
                : cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? cs.primary.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22.sp,
                  color: isSelected ? cs.primary : Colors.grey[500]),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cs.primary : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEVEL PICKER BOTTOM SHEET (grouped by cycle)
  // ═══════════════════════════════════════════════════════════════

  void _showLevelPicker(
    BuildContext parentCtx,
    String? current,
    ValueChanged<String?> onSelected,
  ) {
    final cycleLabels = {
      'primaire': 'Primaire',
      'cem': 'CEM (Moyen)',
      'lycee': 'Lycée (Secondaire)',
    };
    final cycleIcons = {
      'primaire': Icons.child_care_rounded,
      'cem': Icons.school_rounded,
      'lycee': Icons.account_balance_rounded,
    };
    final cycles = ['primaire', 'cem', 'lycee'];

    showModalBottomSheet(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ─────────────────────────────────
              SizedBox(height: 8.h),
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // ── Header ─────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 8.w, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choisir le niveau',
                      style: TextStyle(
                          fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(color: cs.outlineVariant.withOpacity(0.5)),

              // ── "All levels" ───────────────────────────
              ListTile(
                leading: CircleAvatar(
                  radius: 16.r,
                  backgroundColor: current == null
                      ? cs.primaryContainer
                      : Colors.grey[100],
                  child: Icon(Icons.clear_all_rounded,
                      size: 18.sp,
                      color: current == null ? cs.primary : Colors.grey[500]),
                ),
                title: Text(
                  'Tous les niveaux',
                  style: TextStyle(
                    fontWeight:
                        current == null ? FontWeight.w600 : FontWeight.normal,
                    color: current == null ? cs.primary : null,
                  ),
                ),
                trailing: current == null
                    ? Icon(Icons.check_circle_rounded,
                        color: cs.primary, size: 20.sp)
                    : null,
                onTap: () {
                  onSelected(null);
                  Navigator.pop(ctx);
                },
              ),
              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),

              // ── Grouped levels ─────────────────────────
              Flexible(
                child: ListView(
                  padding: EdgeInsets.only(bottom: 24.h),
                  children: _buildGroupedLevelTiles(
                    ctx, current, onSelected, cycles, cycleLabels, cycleIcons, cs,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedLevelTiles(
    BuildContext ctx,
    String? current,
    ValueChanged<String?> onSelected,
    List<String> cycles,
    Map<String, String> cycleLabels,
    Map<String, IconData> cycleIcons,
    ColorScheme cs,
  ) {
    final widgets = <Widget>[];
    for (final cycle in cycles) {
      final levels = Levels.byCycle(cycle);
      if (levels.isEmpty) continue;

      // Section header
      widgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 6.h),
          child: Row(
            children: [
              Icon(cycleIcons[cycle] ?? Icons.school_rounded,
                  size: 16.sp, color: Colors.grey[500]),
              SizedBox(width: 8.w),
              Text(
                cycleLabels[cycle] ?? cycle,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );

      // Level items
      for (final l in levels) {
        final isSelected = current == l.code;
        widgets.add(
          ListTile(
            dense: true,
            selected: isSelected,
            selectedTileColor: cs.primaryContainer.withOpacity(0.3),
            contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
            leading: CircleAvatar(
              radius: 14.r,
              backgroundColor:
                  isSelected ? cs.primaryContainer : Colors.grey[100],
              child: Icon(Icons.school_outlined,
                  size: 15.sp,
                  color: isSelected ? cs.primary : Colors.grey[500]),
            ),
            title: Text(
              l.name,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? cs.primary : null,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded,
                    color: cs.primary, size: 18.sp)
                : null,
            onTap: () {
              onSelected(l.code);
              Navigator.pop(ctx);
            },
          ),
        );
      }
    }
    return widgets;
  }
}
