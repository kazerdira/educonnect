import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/teacher/domain/entities/offering.dart';
import 'package:educonnect/features/booking/presentation/widgets/booking_bottom_sheet.dart';

/// Public teacher profile page visible to students/parents from search results.
class TeacherPublicProfilePage extends StatefulWidget {
  const TeacherPublicProfilePage({
    super.key,
    required this.teacherId,
    this.forChildId,
    this.forChildName,
  });
  final String teacherId;

  /// If a parent is booking for a child, the child's user ID
  final String? forChildId;

  /// The child's name for display purposes
  final String? forChildName;

  @override
  State<TeacherPublicProfilePage> createState() =>
      _TeacherPublicProfilePageState();
}

class _TeacherPublicProfilePageState extends State<TeacherPublicProfilePage> {
  @override
  void initState() {
    super.initState();
    // Fetch profile AND offerings together
    context
        .read<TeacherBloc>()
        .add(TeacherPublicOfferingsRequested(teacherId: widget.teacherId));
  }

  void _refresh() {
    context
        .read<TeacherBloc>()
        .add(TeacherPublicOfferingsRequested(teacherId: widget.teacherId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil enseignant')),
      body: BlocBuilder<TeacherBloc, TeacherState>(
        builder: (context, state) {
          if (state is TeacherLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TeacherError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48.sp, color: Colors.red[300]),
                  SizedBox(height: 12.h),
                  Text(state.message, textAlign: TextAlign.center),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is TeacherPublicProfileLoaded) {
            final p = state.profile;
            final offerings = state.offerings;
            final availability = state.availability;

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  // ── Avatar & name ─────────────────────────────
                  Center(
                    child: CircleAvatar(
                      radius: 48.r,
                      backgroundColor: theme.colorScheme.primary,
                      backgroundImage:
                          p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                              ? NetworkImage(p.avatarUrl!)
                              : null,
                      child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                          ? Text(
                              '${p.firstName.isNotEmpty ? p.firstName[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}'
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 32.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Center(
                    child: Text(
                      '${p.firstName} ${p.lastName}',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (p.wilaya.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              size: 16.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text(p.wilaya,
                              style: TextStyle(
                                  fontSize: 14.sp, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 20.h),

                  // ── Stats row ─────────────────────────────────
                  Row(
                    children: [
                      _statCard(theme,
                          icon: Icons.star,
                          label: 'Note',
                          value: p.ratingAvg.toStringAsFixed(1),
                          color: Colors.amber),
                      SizedBox(width: 8.w),
                      _statCard(theme,
                          icon: Icons.event,
                          label: 'Sessions',
                          value: '${p.totalSessions}',
                          color: Colors.blue),
                      SizedBox(width: 8.w),
                      _statCard(theme,
                          icon: Icons.people,
                          label: 'Élèves',
                          value: '${p.totalStudents}',
                          color: Colors.green),
                    ],
                  ),

                  SizedBox(height: 20.h),

                  // ── Offerings ─────────────────────────────────
                  if (offerings.isNotEmpty) ...[
                    Text('Ce que je propose',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: 12.h),
                    ...offerings.map((o) => _offeringCard(theme, o)),
                    SizedBox(height: 12.h),
                  ],

                  // ── Bio ───────────────────────────────────────
                  if (p.bio.isNotEmpty) ...[
                    Text('À propos',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8.h),
                    Text(p.bio, style: TextStyle(fontSize: 14.sp)),
                    SizedBox(height: 20.h),
                  ],

                  // ── Specializations ───────────────────────────
                  if (p.specializations.isNotEmpty) ...[
                    Text('Spécialisations',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 6.h,
                      children: p.specializations
                          .map((s) => Chip(label: Text(s)))
                          .toList(),
                    ),
                    SizedBox(height: 20.h),
                  ],

                  // ── Info tiles ────────────────────────────────
                  if (p.experienceYears > 0)
                    _infoTile(
                      icon: Icons.work_history,
                      label: 'Expérience',
                      value: '${p.experienceYears} ans',
                    ),
                  _infoTile(
                    icon: Icons.verified,
                    label: 'Statut',
                    value: p.verificationStatus == 'verified'
                        ? 'Vérifié'
                        : 'En attente',
                  ),

                  SizedBox(height: 24.h),

                  // ── Actions ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Réserver une séance'),
                      onPressed: () => _showBookingSheet(
                        p.userId,
                        '${p.firstName} ${p.lastName}',
                        offerings,
                        availability,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Voir les avis'),
                      onPressed: () =>
                          context.push('/reviews/teacher/${widget.teacherId}'),
                    ),
                  ),
                ],
              ),
            );
          }

          // Fallback for old TeacherProfileLoaded state
          if (state is TeacherProfileLoaded) {
            // Trigger the new event to also get offerings
            WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
            return const Center(child: CircularProgressIndicator());
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _offeringCard(ThemeData theme, Offering o) {
    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            // Subject icon
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                o.sessionType == 'group' ? Icons.groups : Icons.person,
                color: theme.colorScheme.primary,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.subjectName,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      _tagChip(
                          o.levelCode.isNotEmpty ? o.levelCode : o.levelName),
                      SizedBox(width: 6.w),
                      _tagChip(o.sessionType == 'group'
                          ? 'Groupe (${o.maxStudents} max)'
                          : 'Individuel'),
                    ],
                  ),
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${o.pricePerHour.toStringAsFixed(0)} DA',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  '/heure',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
      ),
    );
  }

  Widget _statCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24.sp),
              SizedBox(height: 4.h),
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 2.h),
              Text(label,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 22.sp, color: Colors.grey[600]),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
                SizedBox(height: 2.h),
                Text(value, style: TextStyle(fontSize: 15.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(
    String teacherId,
    String teacherName,
    List<Offering> offerings,
    List<dynamic> availability,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => BookingBottomSheet(
          teacherId: teacherId,
          teacherName: teacherName,
          offerings: offerings,
          availability: availability.cast(),
          forChildId: widget.forChildId,
          forChildName: widget.forChildName,
        ),
      ),
    );
  }
}
