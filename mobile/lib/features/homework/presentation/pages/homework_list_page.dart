import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/homework/domain/entities/homework.dart';
import 'package:educonnect/features/homework/presentation/bloc/homework_bloc.dart';

class HomeworkListPage extends StatefulWidget {
  const HomeworkListPage({super.key});

  @override
  State<HomeworkListPage> createState() => _HomeworkListPageState();
}

class _HomeworkListPageState extends State<HomeworkListPage> {
  @override
  void initState() {
    super.initState();
    context.read<HomeworkBloc>().add(HomeworkListRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devoirs')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'homework_list_fab',
        onPressed: () => context.push('/homework/create'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<HomeworkBloc>().add(HomeworkListRequested()),
        child: BlocBuilder<HomeworkBloc, HomeworkState>(
          builder: (context, state) {
            if (state is HomeworkLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is HomeworkError) {
              return Center(child: Text(state.message));
            }
            if (state is HomeworkListLoaded) {
              if (state.homeworks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucun devoir',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.homeworks.length,
                itemBuilder: (_, i) => _homeworkCard(state.homeworks[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _homeworkCard(Homework hw) {
    final dueDate = DateTime.tryParse(hw.dueDate);
    final dueDateStr =
        dueDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(dueDate) : '';
    final isOverdue = dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        hw.status != 'closed';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => context.push('/homework/${hw.id}'),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hw.title,
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _statusChip(hw.status),
                ],
              ),
              SizedBox(height: 6.h),

              // Course name
              Text(
                hw.courseName,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 8.h),

              // Due date + submission count
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14.sp,
                      color: isOverdue ? Colors.red : Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Text(
                    dueDateStr,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight:
                          isOverdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.people_outline,
                      size: 14.sp, color: Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Text(
                    '${hw.submissionCount} soumission${hw.submissionCount > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4.h),

              // Max score
              Row(
                children: [
                  Icon(Icons.star_outline,
                      size: 14.sp, color: Colors.amber[700]),
                  SizedBox(width: 4.w),
                  Text(
                    'Note max: ${hw.maxScore.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'published':
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green;
        label = 'Publié';
        break;
      case 'draft':
        bg = Colors.grey.withValues(alpha: 0.1);
        fg = Colors.grey;
        label = 'Brouillon';
        break;
      case 'closed':
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red;
        label = 'Fermé';
        break;
      default:
        bg = Colors.blue.withValues(alpha: 0.1);
        fg = Colors.blue;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.sp, color: fg)),
    );
  }
}
