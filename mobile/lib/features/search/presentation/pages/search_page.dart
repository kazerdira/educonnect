import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/search/presentation/bloc/search_bloc.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String? _selectedWilaya;
  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Enseignants'),
            Tab(text: 'Cours'),
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
                hintText: 'Rechercher...',
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
                          setState(() {});
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: _showFilters,
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

          // Active filters
          if (_selectedWilaya != null || _selectedLevel != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Wrap(
                spacing: 8.w,
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _teacherResults(),
                _courseResults(),
              ],
            ),
          ),
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
            text: 'Recherchez un enseignant par nom, matière ou wilaya',
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

  Widget _courseResults() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchInitial) {
          return _emptyState(
            icon: Icons.search,
            text: 'Recherchez un cours par titre ou matière',
          );
        }

        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SearchError) {
          return Center(child: Text(state.message));
        }

        if (state is SearchCoursesLoaded) {
          final hits = state.result.hits;
          if (hits.isEmpty) {
            return _emptyState(
              icon: Icons.menu_book_outlined,
              text: 'Aucun cours trouvé',
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: hits.length,
            itemBuilder: (context, index) {
              final course = hits[index] as Map<String, dynamic>;
              return _courseCard(course);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _teacherCard(Map<String, dynamic> teacher) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () {
          final id = teacher['user_id'] ?? teacher['id'] ?? '';
          if (id.toString().isNotEmpty) {
            context.push('/teacher/$id');
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  '${(teacher['first_name'] as String? ?? 'T')[0]}${(teacher['last_name'] as String? ?? '')[0]}'
                      .toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (teacher['wilaya'] != null)
                      Text(
                        teacher['wilaya'],
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14.sp, color: Colors.amber),
                        SizedBox(width: 2.w),
                        Text(
                          '${(teacher['rating_avg'] as num? ?? 0).toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${teacher['total_sessions'] ?? 0} sessions',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _courseCard(Map<String, dynamic> course) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () {
          final id = course['id'] ?? '';
          if (id.toString().isNotEmpty) {
            context.push('/courses/$id');
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course['title'] as String? ?? 'Sans titre',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              if (course['teacher_name'] != null)
                Text(
                  'Par ${course['teacher_name']}',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  if (course['subject_name'] != null) ...[
                    Chip(
                      label: Text(
                        course['subject_name'],
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    SizedBox(width: 8.w),
                  ],
                  if (course['price'] != null)
                    Text(
                      '${(course['price'] as num).toStringAsFixed(0)} DA',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64.sp, color: Colors.grey[400]),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  void _doSearch() {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    if (_tabController.index == 0) {
      context.read<SearchBloc>().add(SearchTeachersRequested(
            query: query,
            wilaya: _selectedWilaya,
            level: _selectedLevel,
          ));
    } else {
      context.read<SearchBloc>().add(SearchCoursesRequested(
            query: query,
            level: _selectedLevel,
          ));
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Wilaya',
                    hintText: 'Ex: Alger',
                    border: const OutlineInputBorder(),
                    suffixIcon: _selectedWilaya != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setSheetState(() => _selectedWilaya = null),
                          )
                        : null,
                  ),
                  controller: TextEditingController(text: _selectedWilaya),
                  onChanged: (v) => _selectedWilaya = v.isEmpty ? null : v,
                ),
                SizedBox(height: 12.h),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Niveau',
                    hintText: 'Ex: 3AS',
                    border: const OutlineInputBorder(),
                    suffixIcon: _selectedLevel != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setSheetState(() => _selectedLevel = null),
                          )
                        : null,
                  ),
                  controller: TextEditingController(text: _selectedLevel),
                  onChanged: (v) => _selectedLevel = v.isEmpty ? null : v,
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {});
                      _doSearch();
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      },
    );
  }
}
