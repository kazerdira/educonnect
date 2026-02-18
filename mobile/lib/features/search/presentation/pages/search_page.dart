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

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SubjectItem {
  final String id;
  final String name;
  const _SubjectItem({required this.id, required this.name});
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String? _selectedWilaya;
  String? _selectedLevel;
  String? _selectedSubject;
  List<_SubjectItem> _subjects = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchSubjects();
  }

  void _onTabChanged() {
    // Only fire on actual tab selection (not animation)
    if (!_tabController.indexIsChanging) return;
    if (_isFormValid) _doSearch();
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

  bool get _isFormValid {
    return _searchController.text.trim().isNotEmpty ||
        _selectedSubject != null ||
        _selectedLevel != null ||
        _selectedWilaya != null;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
            padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 8.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Nom, matière, mot-clé...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          if (_isFormValid) {
                            _doSearch();
                          } else {
                            context.read<SearchBloc>().add(SearchCleared());
                          }
                        },
                      ),
                    IconButton(
                      icon: Badge(
                        isLabelVisible: _selectedWilaya != null,
                        smallSize: 8,
                        child: const Icon(Icons.tune),
                      ),
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

          // Quick subject chips (scrollable row)
          if (_subjects.isNotEmpty)
            SizedBox(
              height: 40.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _subjects.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final subj = _subjects[index];
                  final isSelected = _selectedSubject == subj.name;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(subj.name, style: TextStyle(fontSize: 12.sp)),
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubject = selected ? subj.name : null;
                      });
                      _doSearch();
                    },
                    selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                    checkmarkColor: theme.colorScheme.primary,
                    showCheckmark: true,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              ),
            ),

          // Active filters (level, wilaya)
          if (_selectedLevel != null || _selectedWilaya != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: Wrap(
                spacing: 8.w,
                children: [
                  if (_selectedLevel != null)
                    Chip(
                      avatar: Icon(Icons.school, size: 14.sp),
                      label: Text(
                          Levels.all
                              .firstWhere((l) => l.name == _selectedLevel,
                                  orElse: () => LevelItem(
                                      code: '',
                                      name: _selectedLevel!,
                                      cycle: ''))
                              .name,
                          style: TextStyle(fontSize: 12.sp)),
                      onDeleted: () {
                        setState(() => _selectedLevel = null);
                        if (_isFormValid) _doSearch();
                      },
                    ),
                  if (_selectedWilaya != null)
                    Chip(
                      avatar: Icon(Icons.location_on, size: 14.sp),
                      label: Text(_selectedWilaya!,
                          style: TextStyle(fontSize: 12.sp)),
                      onDeleted: () {
                        setState(() => _selectedWilaya = null);
                        if (_isFormValid) _doSearch();
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
            text:
                'Tapez un nom ou sélectionnez une matière ci-dessus pour trouver un enseignant',
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
    final subjects = (teacher['subjects'] as List?)?.cast<String>() ?? [];
    final levels = (teacher['levels'] as List?)?.cast<String>() ?? [];

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
                    if (subjects.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          subjects.join(', '),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (levels.isNotEmpty)
                      Text(
                        levels.join(', '),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        if (teacher['price_min'] != null) ...[
                          SizedBox(width: 8.w),
                          Text(
                            'dès ${(teacher['price_min'] as num).toStringAsFixed(0)} DA',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
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

    // Need at least a query or a filter
    if (query.isEmpty &&
        _selectedSubject == null &&
        _selectedLevel == null &&
        _selectedWilaya == null) {
      return;
    }

    if (_tabController.index == 0) {
      context.read<SearchBloc>().add(SearchTeachersRequested(
            query: query,
            subject: _selectedSubject,
            wilaya: _selectedWilaya,
            level: _selectedLevel,
          ));
    } else {
      context.read<SearchBloc>().add(SearchCoursesRequested(
            query: query,
            subject: _selectedSubject,
            level: _selectedLevel,
          ));
    }
  }

  void _showFilters() {
    // Local copies for the sheet
    String? tempWilaya = _selectedWilaya;
    String? tempLevel = _selectedLevel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtres avancés',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (tempWilaya != null || tempLevel != null)
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempWilaya = null;
                              tempLevel = null;
                            });
                          },
                          child: const Text('Réinitialiser'),
                        ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Level dropdown
                  DropdownButtonFormField<String>(
                    value: tempLevel,
                    decoration: InputDecoration(
                      labelText: 'Niveau scolaire',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                    isExpanded: true,
                    hint: const Text('Tous les niveaux'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tous les niveaux'),
                      ),
                      ...Levels.all.map((l) => DropdownMenuItem(
                            value: l.name,
                            child: Text('${l.name}'),
                          )),
                    ],
                    onChanged: (v) => setSheetState(() => tempLevel = v),
                  ),
                  SizedBox(height: 16.h),

                  // Wilaya dropdown
                  DropdownButtonFormField<String>(
                    value: tempWilaya,
                    decoration: InputDecoration(
                      labelText: 'Wilaya',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    isExpanded: true,
                    hint: const Text('Toutes les wilayas'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Toutes les wilayas'),
                      ),
                      ...Wilayas.all.map((w) => DropdownMenuItem(
                            value: w,
                            child: Text(w, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setSheetState(() => tempWilaya = v),
                  ),
                  SizedBox(height: 24.h),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Appliquer les filtres'),
                      onPressed: () {
                        setState(() {
                          _selectedWilaya = tempWilaya;
                          _selectedLevel = tempLevel;
                        });
                        Navigator.pop(ctx);
                        _doSearch();
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
  }
}
