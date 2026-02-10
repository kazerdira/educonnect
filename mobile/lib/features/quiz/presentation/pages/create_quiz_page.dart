import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/quiz/presentation/bloc/quiz_bloc.dart';

class CreateQuizPage extends StatefulWidget {
  const CreateQuizPage({super.key});

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _maxAttemptsCtrl = TextEditingController(text: '1');
  final _passingScoreCtrl = TextEditingController(text: '50');
  final _courseIdCtrl = TextEditingController();
  final _chapterIdCtrl = TextEditingController();
  final _lessonIdCtrl = TextEditingController();

  String _status = 'draft';

  /// Each question is a map: { "question": "...", "options": [...], "answer": ... }
  final List<Map<String, dynamic>> _questions = [];

  // Controllers for the "add question" form
  final _qTextCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _maxAttemptsCtrl.dispose();
    _passingScoreCtrl.dispose();
    _courseIdCtrl.dispose();
    _chapterIdCtrl.dispose();
    _lessonIdCtrl.dispose();
    _qTextCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un quiz')),
      body: BlocListener<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state is QuizCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quiz créé avec succès !')),
            );
            Navigator.pop(context);
          }
          if (state is QuizError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course ID
                TextFormField(
                  controller: _courseIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID du cours *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                SizedBox(height: 16.h),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titre *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 3) ? 'Min 3 caractères' : null,
                ),
                SizedBox(height: 16.h),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                SizedBox(height: 16.h),

                // Duration (minutes)
                TextFormField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée (minutes) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Durée requise'
                      : null,
                ),
                SizedBox(height: 16.h),

                // Max attempts
                TextFormField(
                  controller: _maxAttemptsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre max de tentatives *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Requis' : null,
                ),
                SizedBox(height: 16.h),

                // Passing score
                TextFormField(
                  controller: _passingScoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Score de réussite (%) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 100) {
                      return 'Entre 0 et 100';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                // Chapter ID (optional)
                TextFormField(
                  controller: _chapterIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID du chapitre (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),

                // Lesson ID (optional)
                TextFormField(
                  controller: _lessonIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID de la leçon (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),

                // Status toggle
                SwitchListTile(
                  title: const Text('Publier maintenant'),
                  value: _status == 'published',
                  onChanged: (v) =>
                      setState(() => _status = v ? 'published' : 'draft'),
                ),
                SizedBox(height: 24.h),

                // ── Questions section ────────────────────
                Text('Questions',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w600)),
                SizedBox(height: 8.h),

                if (_questions.isEmpty)
                  Text('Aucune question ajoutée.',
                      style:
                          TextStyle(fontSize: 13.sp, color: Colors.grey[500]))
                else
                  ..._questions.asMap().entries.map(_questionTile),

                SizedBox(height: 16.h),
                _addQuestionForm(),

                SizedBox(height: 24.h),

                // Submit button
                BlocBuilder<QuizBloc, QuizState>(
                  builder: (context, state) {
                    final loading = state is QuizLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const CircularProgressIndicator()
                            : const Text('Créer le quiz'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Question tile ──────────────────────────────────────────

  Widget _questionTile(MapEntry<int, Map<String, dynamic>> entry) {
    final idx = entry.key;
    final q = entry.value;
    final options = q['options'] as List<dynamic>? ?? [];

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: CircleAvatar(child: Text('${idx + 1}')),
        title: Text(q['question'] as String? ?? ''),
        subtitle: Text(
          '${options.length} option${options.length > 1 ? 's' : ''}  •  Réponse: ${q['answer']}',
          style: TextStyle(fontSize: 12.sp),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => setState(() => _questions.removeAt(idx)),
        ),
      ),
    );
  }

  // ── Add-question inline form ───────────────────────────────

  Widget _addQuestionForm() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajouter une question',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),

          // Question text
          TextFormField(
            controller: _qTextCtrl,
            decoration: const InputDecoration(
              labelText: 'Texte de la question',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 8.h),

          // Options
          ...List.generate(_optionCtrls.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Radio<int>(
                    value: i,
                    groupValue: _correctIndex,
                    onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _optionCtrls[i],
                      decoration: InputDecoration(
                        labelText: 'Option ${i + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_optionCtrls.length > 2)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _optionCtrls[i].dispose();
                          _optionCtrls.removeAt(i);
                          if (_correctIndex >= _optionCtrls.length) {
                            _correctIndex = 0;
                          }
                        });
                      },
                    ),
                ],
              ),
            );
          }),

          TextButton.icon(
            onPressed: () =>
                setState(() => _optionCtrls.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une option'),
          ),
          SizedBox(height: 8.h),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _addQuestion,
              child: const Text('Ajouter cette question'),
            ),
          ),
        ],
      ),
    );
  }

  void _addQuestion() {
    final text = _qTextCtrl.text.trim();
    if (text.isEmpty) return;

    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Au moins 2 options requises')),
      );
      return;
    }

    setState(() {
      _questions.add({
        'question': text,
        'options': options,
        'answer': _correctIndex < options.length ? _correctIndex : 0,
      });
      _qTextCtrl.clear();
      for (final c in _optionCtrls) {
        c.text = '';
      }
      _correctIndex = 0;
    });
  }

  // ── Submit ─────────────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une question')),
      );
      return;
    }

    context.read<QuizBloc>().add(
          CreateQuizRequested(
            courseId: _courseIdCtrl.text.trim(),
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            duration: int.parse(_durationCtrl.text.trim()),
            maxAttempts: int.parse(_maxAttemptsCtrl.text.trim()),
            passingScore: double.parse(_passingScoreCtrl.text.trim()),
            questions: _questions,
            status: _status,
            chapterId: _chapterIdCtrl.text.trim().isNotEmpty
                ? _chapterIdCtrl.text.trim()
                : null,
            lessonId: _lessonIdCtrl.text.trim().isNotEmpty
                ? _lessonIdCtrl.text.trim()
                : null,
          ),
        );
  }
}
