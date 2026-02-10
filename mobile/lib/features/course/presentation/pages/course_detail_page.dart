import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/course/domain/entities/course.dart';
import 'package:educonnect/features/course/presentation/bloc/course_bloc.dart';

class CourseDetailPage extends StatefulWidget {
  final String courseId;
  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<CourseBloc>()
        .add(CourseDetailRequested(courseId: widget.courseId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du cours')),
      body: BlocConsumer<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseEnrolled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Inscription réussie !')),
            );
          }
          if (state is ChapterAdded || state is LessonAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ajouté avec succès')),
            );
            context
                .read<CourseBloc>()
                .add(CourseDetailRequested(courseId: widget.courseId));
          }
          if (state is CourseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is CourseLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CourseDetailLoaded) {
            return _body(state.course);
          }
          if (state is CourseError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _body(Course course) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(course.title,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),

          if (course.description != null && course.description!.isNotEmpty) ...[
            Text(course.description!,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700])),
            SizedBox(height: 16.h),
          ],

          // Info chips
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: [
              if (course.subjectName != null)
                Chip(label: Text(course.subjectName!)),
              if (course.levelName != null)
                Chip(label: Text(course.levelName!)),
              Chip(
                avatar: const Icon(Icons.people, size: 16),
                label: Text('${course.enrollmentCount} inscrits'),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Price + enroll
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prix',
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.grey[500])),
                        Text('${course.price.toStringAsFixed(0)} DA',
                            style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context
                        .read<CourseBloc>()
                        .add(EnrollCourseRequested(courseId: course.id)),
                    child: const Text('S\'inscrire'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Chapters + lessons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chapitres',
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _addChapterDialog(course),
              ),
            ],
          ),
          if (course.chapters.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text('Aucun chapitre',
                  style: TextStyle(color: Colors.grey[500])),
            )
          else
            ...course.chapters.map((ch) => _chapterTile(course, ch)),
        ],
      ),
    );
  }

  Widget _chapterTile(Course course, Chapter chapter) {
    return ExpansionTile(
      title: Text('${chapter.order}. ${chapter.title}'),
      trailing: IconButton(
        icon: const Icon(Icons.add, size: 20),
        onPressed: () => _addLessonDialog(course, chapter),
      ),
      children: chapter.lessons.isEmpty
          ? [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text('Aucune leçon',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13.sp)),
              ),
            ]
          : chapter.lessons.map((l) => _lessonTile(l)).toList(),
    );
  }

  Widget _lessonTile(Lesson lesson) {
    return ListTile(
      leading: Icon(
        lesson.videoUrl != null ? Icons.play_circle_outline : Icons.article,
        color: lesson.isPreview ? Colors.blue : Colors.grey,
      ),
      title: Text(lesson.title),
      subtitle: Text(
        '${lesson.duration} min${lesson.isPreview ? ' • Aperçu' : ''}',
        style: TextStyle(fontSize: 12.sp),
      ),
    );
  }

  void _addChapterDialog(Course course) {
    final titleCtrl = TextEditingController();
    final orderCtrl =
        TextEditingController(text: '${course.chapters.length + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un chapitre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Titre', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: orderCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Ordre', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              context.read<CourseBloc>().add(AddChapterRequested(
                    courseId: course.id,
                    title: titleCtrl.text.trim(),
                    order: int.tryParse(orderCtrl.text) ?? 0,
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _addLessonDialog(Course course, Chapter chapter) {
    final titleCtrl = TextEditingController();
    final orderCtrl =
        TextEditingController(text: '${chapter.lessons.length + 1}');
    bool isPreview = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter une leçon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Titre', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Ordre', border: OutlineInputBorder()),
              ),
              SizedBox(height: 8.h),
              CheckboxListTile(
                title: const Text('Aperçu gratuit'),
                value: isPreview,
                onChanged: (v) => setDialogState(() => isPreview = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                context.read<CourseBloc>().add(AddLessonRequested(
                      courseId: course.id,
                      title: titleCtrl.text.trim(),
                      order: int.tryParse(orderCtrl.text) ?? 0,
                      isPreview: isPreview,
                    ));
                Navigator.pop(ctx);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
