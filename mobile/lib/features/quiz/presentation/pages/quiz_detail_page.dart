import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/quiz/domain/entities/quiz.dart';
import 'package:educonnect/features/quiz/presentation/bloc/quiz_bloc.dart';

class QuizDetailPage extends StatefulWidget {
  final String quizId;

  /// Set to true when the current user is a teacher (shows results).
  /// When false the student attempt UI is shown.
  final bool isTeacher;

  const QuizDetailPage({
    super.key,
    required this.quizId,
    this.isTeacher = false,
  });

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<QuizBloc>().add(QuizDetailRequested(quizId: widget.quizId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du quiz')),
      body: BlocConsumer<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state is AttemptSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.attempt.passed
                      ? 'Réussi ! Score: ${state.attempt.score.toStringAsFixed(1)}%'
                      : 'Échoué. Score: ${state.attempt.score.toStringAsFixed(1)}%',
                ),
              ),
            );
            // Reload quiz detail
            context
                .read<QuizBloc>()
                .add(QuizDetailRequested(quizId: widget.quizId));
          }
          if (state is QuizError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is QuizLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is QuizDetailLoaded) {
            return _body(state.quiz);
          }
          if (state is QuizResultsLoaded) {
            return _resultsBody(state.results);
          }
          if (state is QuizError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ── Quiz info body ──────────────────────────────────────────

  Widget _body(Quiz quiz) {
    final createdAt = DateTime.tryParse(quiz.createdAt);
    final createdStr = createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
        : '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────
          Text(quiz.title,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),

          // ── Meta info chips ────────────────────────
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: [
              Chip(label: Text(quiz.courseName)),
              Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(quiz.teacherName),
              ),
              Chip(
                avatar: const Icon(Icons.timer, size: 16),
                label: Text('${quiz.duration} min'),
              ),
              Chip(
                avatar: const Icon(Icons.repeat, size: 16),
                label: Text(
                    '${quiz.maxAttempts} tentative${quiz.maxAttempts > 1 ? 's' : ''}'),
              ),
              Chip(
                avatar: const Icon(Icons.check_circle, size: 16),
                label: Text('Min: ${quiz.passingScore.toStringAsFixed(0)}%'),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // ── Description ────────────────────────────
          if (quiz.description.isNotEmpty) ...[
            Text('Description',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 4.h),
            Text(quiz.description,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700])),
            SizedBox(height: 16.h),
          ],

          // ── Questions count ────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 20.sp, color: Colors.blue),
                SizedBox(width: 8.w),
                Text(
                  '${quiz.questions.length} question${quiz.questions.length > 1 ? 's' : ''}',
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // ── Created date ───────────────────────────
          Text(
            'Créé le $createdStr',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 24.h),

          const Divider(),
          SizedBox(height: 16.h),

          // ── Role-specific section ──────────────────
          if (widget.isTeacher)
            _teacherSection(quiz)
          else
            _studentSection(quiz),
        ],
      ),
    );
  }

  // ── Student section: start attempt ──────────────────────────

  Widget _studentSection(Quiz quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Passer le quiz',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 8.h),
        Text(
          'Vous disposez de ${quiz.duration} minutes et ${quiz.maxAttempts} tentative${quiz.maxAttempts > 1 ? 's' : ''} pour compléter ce quiz.',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            onPressed:
                quiz.status == 'published' ? () => _startAttempt(quiz) : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              quiz.status == 'published'
                  ? 'Commencer le quiz'
                  : 'Quiz non disponible',
            ),
          ),
        ),
      ],
    );
  }

  void _startAttempt(Quiz quiz) {
    // For now, submit empty answers to start / create an attempt.
    // A full question-by-question UI can be layered on top later.
    context.read<QuizBloc>().add(
          SubmitAttemptRequested(quizId: quiz.id, answers: []),
        );
  }

  // ── Teacher section: view results ───────────────────────────

  Widget _teacherSection(Quiz quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Résultats',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: OutlinedButton.icon(
            onPressed: () => context
                .read<QuizBloc>()
                .add(QuizResultsRequested(quizId: quiz.id)),
            icon: const Icon(Icons.bar_chart),
            label: const Text('Voir les résultats'),
          ),
        ),
      ],
    );
  }

  // ── Results body ────────────────────────────────────────────

  Widget _resultsBody(QuizResults results) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Résultats du quiz',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 16.h),

          // ── Summary cards ──────────────────────────
          Row(
            children: [
              _summaryCard(
                  'Tentatives', results.totalAttempts.toString(), Icons.people),
              SizedBox(width: 8.w),
              _summaryCard('Moyenne',
                  '${results.averageScore.toStringAsFixed(1)}%', Icons.score),
              SizedBox(width: 8.w),
              _summaryCard('Taux réussite',
                  '${results.passRate.toStringAsFixed(1)}%', Icons.check),
            ],
          ),
          SizedBox(height: 24.h),

          // ── Attempts list ──────────────────────────
          Text('Tentatives',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),

          if (results.attempts.isEmpty)
            Text('Aucune tentative pour le moment.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]))
          else
            ...results.attempts.map(_attemptTile),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            children: [
              Icon(icon, size: 24.sp, color: Colors.blue),
              SizedBox(height: 4.h),
              Text(value,
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 2.h),
              Text(label,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attemptTile(QuizAttempt attempt) {
    final startedAt = DateTime.tryParse(attempt.startedAt);
    final startedStr = startedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(startedAt)
        : '';

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(
          attempt.passed ? Icons.check_circle : Icons.cancel,
          color: attempt.passed ? Colors.green : Colors.red,
        ),
        title: Text(attempt.studentName),
        subtitle: Text('$startedStr  •  ${attempt.score.toStringAsFixed(1)}%'),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: attempt.passed ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            attempt.passed ? 'Réussi' : 'Échoué',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color:
                  attempt.passed ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
