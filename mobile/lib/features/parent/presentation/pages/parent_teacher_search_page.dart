import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/core/constants/wilayas.dart';
import 'package:educonnect/core/constants/levels.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/search/presentation/bloc/search_bloc.dart';

/// Search page for parents to find teachers for their children.
/// Unlike the regular search page, this passes child info when navigating
/// to teacher profiles so bookings are made on behalf of the child.
class ParentTeacherSearchPage extends StatefulWidget {
  const ParentTeacherSearchPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  State<ParentTeacherSearchPage> createState() =>
      _ParentTeacherSearchPageState();
}

class _SubjectItem {
  final String id;
  final String name;
  const _SubjectItem({required this.id, required this.name});
}

class _ParentTeacherSearchPageState extends State<ParentTeacherSearchPage> {
  final _searchController = TextEditingController();
  String? _selectedWilaya;
  String? _selectedLevel;
  String? _selectedSubject;
  List<_SubjectItem> _subjects = [];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    try {
      final api = getIt<ApiClient>();
      final response = await api.dio.get(ApiConstants.subjects);
      final data = response.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _subjects = data
            .map((e) => _SubjectItem(
                  id: e['id'] as String? ?? '',
                  name: e['name_fr'] as String? ?? e['name'] as String? ?? '',
                ))
            .toList();
      });
    } catch (_) {
      // Silently fail - subjects will just be empty
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _doSearch() {
    context.read<SearchBloc>().add(SearchTeachersRequested(
          query: _searchController.text.trim(),
          wilaya: _selectedWilaya,
          subject: _selectedSubject,
          level: _selectedLevel,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trouver un prof'),
            Text(
              'pour ${widget.childName}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un enseignant...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<SearchBloc>().add(SearchCleared());
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: _showFiltersSheet,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
          ),

          // Active filters display
          if (_selectedWilaya != null ||
              _selectedSubject != null ||
              _selectedLevel != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  if (_selectedWilaya != null)
                    Chip(
                      label: Text(_selectedWilaya!,
                          style: TextStyle(fontSize: 12.sp)),
                      onDeleted: () {
                        setState(() => _selectedWilaya = null);
                        _doSearch();
                      },
                    ),
                  if (_selectedSubject != null)
                    Chip(
                      label: Text(
                          _subjects
                              .firstWhere((s) => s.id == _selectedSubject,
                                  orElse: () =>
                                      const _SubjectItem(id: '', name: ''))
                              .name,
                          style: TextStyle(fontSize: 12.sp)),
                      onDeleted: () {
                        setState(() => _selectedSubject = null);
                        _doSearch();
                      },
                    ),
                  if (_selectedLevel != null)
                    Chip(
                      label: Text(_selectedLevel!,
                          style: TextStyle(fontSize: 12.sp)),
                      onDeleted: () {
                        setState(() => _selectedLevel = null);
                        _doSearch();
                      },
                    ),
                ],
              ),
            ),

          // Results
          Expanded(child: _teacherResults()),
        ],
      ),
    );
  }

  Widget _teacherResults() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchInitial) {
          return _emptyState(
            icon: Icons.search,
            text: 'Recherchez un enseignant pour ${widget.childName}',
          );
        }

        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SearchError) {
          return Center(child: Text(state.message));
        }

        if (state is SearchTeachersLoaded) {
          final hits = state.result.hits;
          if (hits.isEmpty) {
            return _emptyState(
              icon: Icons.person_off_outlined,
              text: 'Aucun enseignant trouvé',
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: hits.length,
            itemBuilder: (context, index) {
              final teacher = hits[index] as Map<String, dynamic>;
              return _teacherCard(teacher);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _emptyState({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64.sp, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(
            text,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _teacherCard(Map<String, dynamic> teacher) {
    final theme = Theme.of(context);
    final id = teacher['id'] as String? ?? '';
    final firstName = teacher['first_name'] as String? ?? '';
    final lastName = teacher['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final avatar = teacher['avatar_url'] as String?;
    final wilaya = teacher['wilaya'] as String?;
    final subjects = teacher['subjects'] as List<dynamic>? ?? [];
    final rating = (teacher['average_rating'] ?? 0.0) as num;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () {
          // Navigate with child info for parent booking
          context.push(
            '/teacher/$id',
            extra: {
              'forChildId': widget.childId,
              'forChildName': widget.childName,
            },
          );
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: theme.colorScheme.primary,
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (wilaya != null && wilaya.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text(
                            wilaya,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (subjects.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Wrap(
                        spacing: 4.w,
                        runSpacing: 2.h,
                        children: subjects.take(3).map((s) {
                          final subName =
                              s['name_fr'] ?? s['name'] ?? s.toString();
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              subName,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (rating > 0) ...[
                SizedBox(width: 8.w),
                Column(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 20.sp),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Container(
          padding: EdgeInsets.all(16.w),
          child: ListView(
            controller: controller,
            children: [
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),

              // Wilaya selector
              Text('Wilaya', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String?>(
                value: _selectedWilaya,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Sélectionner une wilaya',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Toutes')),
                  ...Wilayas.all
                      .map((w) => DropdownMenuItem(value: w, child: Text(w))),
                ],
                onChanged: (v) => setState(() => _selectedWilaya = v),
              ),
              SizedBox(height: 16.h),

              // Subject selector
              Text('Matière', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String?>(
                value: _selectedSubject,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Sélectionner une matière',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Toutes')),
                  ..._subjects.map((s) =>
                      DropdownMenuItem(value: s.id, child: Text(s.name))),
                ],
                onChanged: (v) => setState(() => _selectedSubject = v),
              ),
              SizedBox(height: 16.h),

              // Level selector
              Text('Niveau', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String?>(
                value: _selectedLevel,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Sélectionner un niveau',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
                  ...Levels.all.map((l) =>
                      DropdownMenuItem(value: l.code, child: Text(l.name))),
                ],
                onChanged: (v) => setState(() => _selectedLevel = v),
              ),
              SizedBox(height: 24.h),

              // Apply button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _doSearch();
                  },
                  child: const Text('Appliquer les filtres'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
