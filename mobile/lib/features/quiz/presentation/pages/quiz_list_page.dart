import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/quiz/domain/entities/quiz.dart';
import 'package:educonnect/features/quiz/presentation/bloc/quiz_bloc.dart';

class QuizListPage extends StatefulWidget {
  const QuizListPage({super.key});

  @override
  State<QuizListPage> createState() => _QuizListPageState();
}

class _QuizListPageState extends State<QuizListPage> {
  @override
  void initState() {
    super.initState();
    context.read<QuizBloc>().add(QuizListRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'quiz_list_fab',
        onPressed: () => context.push('/quiz/create'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<QuizBloc>().add(QuizListRequested()),
        child: BlocBuilder<QuizBloc, QuizState>(
          builder: (context, state) {
            if (state is QuizLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is QuizError) {
              return Center(child: Text(state.message));
            }
            if (state is QuizListLoaded) {
              if (state.quizzes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_outlined,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucun quiz',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.quizzes.length,
                itemBuilder: (_, i) => _quizCard(state.quizzes[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _quizCard(Quiz quiz) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => context.push('/quiz/${quiz.id}'),
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
                      quiz.title,
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _statusChip(quiz.status),
                ],
              ),
              SizedBox(height: 6.h),

              // Course name
              Text(
                quiz.courseName,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 8.h),

              // Duration + max attempts
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14.sp, color: Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Text(
                    '${quiz.duration} min',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 16.w),
                  Icon(Icons.repeat, size: 14.sp, color: Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Text(
                    '${quiz.maxAttempts} tentative${quiz.maxAttempts > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4.h),

              // Passing score + questions count
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14.sp, color: Colors.green[600]),
                  SizedBox(width: 4.w),
                  Text(
                    'Score min: ${quiz.passingScore.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 16.w),
                  Icon(Icons.help_outline,
                      size: 14.sp, color: Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Text(
                    '${quiz.questions.length} question${quiz.questions.length > 1 ? 's' : ''}',
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
    switch (status) {
      case 'published':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'closed':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default: // draft
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 11.sp, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
