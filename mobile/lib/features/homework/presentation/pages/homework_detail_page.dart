import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/homework/domain/entities/homework.dart';
import 'package:educonnect/features/homework/presentation/bloc/homework_bloc.dart';

class HomeworkDetailPage extends StatefulWidget {
  final String homeworkId;

  /// Set to true when the current user is a teacher (shows submissions list
  /// and grading UI). When false the student submission form is shown.
  final bool isTeacher;

  const HomeworkDetailPage({
    super.key,
    required this.homeworkId,
    this.isTeacher = false,
  });

  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  // Student submit form controllers
  final _contentCtrl = TextEditingController();
  final _attachmentCtrl = TextEditingController();

  // Teacher grade form controllers
  final _gradeCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context
        .read<HomeworkBloc>()
        .add(HomeworkDetailRequested(homeworkId: widget.homeworkId));
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _attachmentCtrl.dispose();
    _gradeCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du devoir')),
      body: BlocConsumer<HomeworkBloc, HomeworkState>(
        listener: (context, state) {
          if (state is HomeworkSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Devoir soumis avec succès !')),
            );
            context
                .read<HomeworkBloc>()
                .add(HomeworkDetailRequested(homeworkId: widget.homeworkId));
          }
          if (state is HomeworkGraded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note attribuée avec succès !')),
            );
            context
                .read<HomeworkBloc>()
                .add(HomeworkDetailRequested(homeworkId: widget.homeworkId));
          }
          if (state is HomeworkError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is HomeworkLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HomeworkDetailLoaded) {
            return _body(state.homework);
          }
          if (state is HomeworkError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _body(Homework hw) {
    final dueDate = DateTime.tryParse(hw.dueDate);
    final dueDateStr =
        dueDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(dueDate) : '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────
          Text(hw.title,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),

          // ── Meta info chips ────────────────────────
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: [
              Chip(label: Text(hw.courseName)),
              Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(hw.teacherName),
              ),
              Chip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(dueDateStr),
              ),
              Chip(
                avatar: const Icon(Icons.star, size: 16),
                label: Text('Max: ${hw.maxScore.toStringAsFixed(0)}'),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // ── Description ────────────────────────────
          if (hw.description.isNotEmpty) ...[
            Text('Description',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 4.h),
            Text(hw.description,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700])),
            SizedBox(height: 16.h),
          ],

          // ── Instructions ───────────────────────────
          if (hw.instructions.isNotEmpty) ...[
            Text('Instructions',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 4.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Text(hw.instructions, style: TextStyle(fontSize: 14.sp)),
            ),
            SizedBox(height: 16.h),
          ],

          // ── Attachment link ────────────────────────
          if (hw.attachmentUrl != null && hw.attachmentUrl!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.attach_file, size: 16.sp, color: Colors.blue),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    hw.attachmentUrl!,
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],

          // ── Submission count ───────────────────────
          Text(
            '${hw.submissionCount} soumission${hw.submissionCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 24.h),

          const Divider(),
          SizedBox(height: 16.h),

          // ── Role-specific section ──────────────────
          if (widget.isTeacher)
            _teacherGradeSection(hw)
          else
            _studentSubmitSection(hw),
        ],
      ),
    );
  }

  // ── Student: submit form ─────────────────────────────────────
  Widget _studentSubmitSection(Homework hw) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Soumettre votre travail',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _contentCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Contenu de la réponse *',
            hintText: 'Écrivez votre réponse ici...',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _attachmentCtrl,
          decoration: const InputDecoration(
            labelText: 'Lien de pièce jointe (optionnel)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_file),
          ),
        ),
        SizedBox(height: 16.h),
        BlocBuilder<HomeworkBloc, HomeworkState>(
          builder: (context, state) {
            final loading = state is HomeworkLoading;
            return SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: loading ? null : () => _submitHomework(hw),
                icon: const Icon(Icons.send),
                label: loading
                    ? const CircularProgressIndicator()
                    : const Text('Soumettre'),
              ),
            );
          },
        ),
      ],
    );
  }

  void _submitHomework(Homework hw) {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le contenu est requis')),
      );
      return;
    }
    context.read<HomeworkBloc>().add(SubmitHomeworkRequested(
          homeworkId: hw.id,
          content: content,
          attachmentUrl: _attachmentCtrl.text.trim().isEmpty
              ? null
              : _attachmentCtrl.text.trim(),
        ));
  }

  // ── Teacher: grade section ───────────────────────────────────
  Widget _teacherGradeSection(Homework hw) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notation',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _gradeCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Note (sur ${hw.maxScore.toStringAsFixed(0)}) *',
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _feedbackCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Commentaire (optionnel)',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16.h),
        BlocBuilder<HomeworkBloc, HomeworkState>(
          builder: (context, state) {
            final loading = state is HomeworkLoading;
            return SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: loading ? null : () => _gradeHomework(hw),
                icon: const Icon(Icons.check_circle),
                label: loading
                    ? const CircularProgressIndicator()
                    : const Text('Attribuer la note'),
              ),
            );
          },
        ),
      ],
    );
  }

  void _gradeHomework(Homework hw) {
    final grade = double.tryParse(_gradeCtrl.text.trim());
    if (grade == null || grade < 0 || grade > hw.maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Entrez une note valide entre 0 et ${hw.maxScore.toStringAsFixed(0)}'),
        ),
      );
      return;
    }
    context.read<HomeworkBloc>().add(GradeHomeworkRequested(
          homeworkId: hw.id,
          grade: grade,
          feedback: _feedbackCtrl.text.trim().isEmpty
              ? null
              : _feedbackCtrl.text.trim(),
          status: 'graded',
        ));
  }
}
