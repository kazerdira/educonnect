import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/teacher/domain/entities/offering.dart';

class TeacherOfferingsPage extends StatefulWidget {
  const TeacherOfferingsPage({super.key});

  @override
  State<TeacherOfferingsPage> createState() => _TeacherOfferingsPageState();
}

class _TeacherOfferingsPageState extends State<TeacherOfferingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<TeacherBloc>().add(TeacherOfferingsRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes offres'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actives'),
            Tab(text: 'Désactivées'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'offerings_fab',
        onPressed: () => context.push('/teacher/offerings/create'),
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<TeacherBloc, TeacherState>(
        listener: (context, state) {
          if (state is TeacherOfferingDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offre supprimée'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<TeacherBloc>().add(TeacherOfferingsRequested());
          } else if (state is TeacherOfferingUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.offering.isActive
                      ? 'Offre activée'
                      : 'Offre désactivée',
                ),
                backgroundColor: Colors.green,
              ),
            );
            context.read<TeacherBloc>().add(TeacherOfferingsRequested());
          } else if (state is TeacherOfferingCreated) {
            context.read<TeacherBloc>().add(TeacherOfferingsRequested());
          }
        },
        builder: (context, state) {
          if (state is TeacherLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TeacherError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<TeacherBloc>()
                        .add(TeacherOfferingsRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is TeacherOfferingsLoaded) {
            final activeOfferings =
                state.offerings.where((o) => o.isActive).toList();
            final inactiveOfferings =
                state.offerings.where((o) => !o.isActive).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildOfferingsList(activeOfferings, theme, isActiveTab: true),
                _buildOfferingsList(inactiveOfferings, theme,
                    isActiveTab: false),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOfferingsList(
    List<Offering> offerings,
    ThemeData theme, {
    required bool isActiveTab,
  }) {
    if (offerings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActiveTab
                  ? Icons.library_books_outlined
                  : Icons.pause_circle_outline,
              size: 64.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12.h),
            Text(
              isActiveTab
                  ? 'Aucune offre active'
                  : 'Aucune offre désactivée',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
            ),
            SizedBox(height: 8.h),
            Text(
              isActiveTab
                  ? 'Créez une offre pour commencer'
                  : 'Les offres désactivées apparaîtront ici',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TeacherBloc>().add(TeacherOfferingsRequested());
      },
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: offerings.length,
        itemBuilder: (context, index) {
          return _offeringCard(offerings[index], theme);
        },
      ),
    );
  }

  Widget _offeringCard(Offering offering, ThemeData theme) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offering.subjectName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: offering.isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    offering.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: offering.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Niveau: ${offering.levelName}',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16.sp, color: Colors.green),
                Text(
                  '${offering.pricePerHour.toStringAsFixed(0)} DA/h',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(width: 16.w),
                Icon(Icons.group, size: 16.sp, color: Colors.blue),
                SizedBox(width: 4.w),
                Text(
                  offering.sessionType == 'one_on_one'
                      ? 'Individuel'
                      : 'Groupe (max ${offering.maxStudents})',
                  style: TextStyle(fontSize: 13.sp),
                ),
              ],
            ),
            if (offering.freeTrialEnabled) ...[
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.card_giftcard, size: 16.sp, color: Colors.orange),
                  SizedBox(width: 4.w),
                  Text(
                    'Essai gratuit: ${offering.freeTrialDuration} min',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // Toggle active/inactive
                    context.read<TeacherBloc>().add(
                          TeacherOfferingUpdateRequested(
                            offeringId: offering.id,
                            isActive: !offering.isActive,
                          ),
                        );
                  },
                  icon: Icon(
                    offering.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 18.sp,
                    color: offering.isActive ? Colors.orange : Colors.green,
                  ),
                  label: Text(
                    offering.isActive ? 'Désactiver' : 'Activer',
                    style: TextStyle(
                      color: offering.isActive ? Colors.orange : Colors.green,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(offering),
                  icon: Icon(Icons.delete_outline,
                      size: 18.sp, color: Colors.red),
                  label: const Text(
                    'Supprimer',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Offering offering) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'offre'),
        content: Text(
          'Voulez-vous vraiment supprimer l\'offre "${offering.subjectName}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TeacherBloc>().add(
                    TeacherOfferingDeleteRequested(offeringId: offering.id),
                  );
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
