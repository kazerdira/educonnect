import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/course/domain/entities/course.dart';
import 'package:educonnect/features/course/presentation/bloc/course_bloc.dart';

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  @override
  void initState() {
    super.initState();
    context.read<CourseBloc>().add(CoursesListRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cours')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'course_list_fab',
        onPressed: () => context.push('/courses/create'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<CourseBloc>().add(CoursesListRequested()),
        child: BlocConsumer<CourseBloc, CourseState>(
          listener: (context, state) {
            if (state is CourseDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cours supprimé')),
              );
              context.read<CourseBloc>().add(CoursesListRequested());
            }
          },
          builder: (context, state) {
            if (state is CourseLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CourseError) {
              return Center(child: Text(state.message));
            }
            if (state is CoursesLoaded) {
              if (state.courses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucun cours',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.courses.length,
                itemBuilder: (_, i) => _courseCard(state.courses[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _courseCard(Course course) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => context.push('/courses/${course.id}'),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (course.isPublished)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text('Publié',
                          style:
                              TextStyle(fontSize: 11.sp, color: Colors.green)),
                    )
                  else
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text('Brouillon',
                          style:
                              TextStyle(fontSize: 11.sp, color: Colors.grey)),
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  if (course.subjectName != null) ...[
                    Icon(Icons.school, size: 14.sp, color: Colors.grey),
                    SizedBox(width: 4.w),
                    Text(course.subjectName!,
                        style: TextStyle(
                            fontSize: 12.sp, color: Colors.grey[600])),
                    SizedBox(width: 12.w),
                  ],
                  Icon(Icons.people, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text('${course.enrollmentCount} inscrits',
                      style:
                          TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                  const Spacer(),
                  Text('${course.price.toStringAsFixed(0)} DA',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
