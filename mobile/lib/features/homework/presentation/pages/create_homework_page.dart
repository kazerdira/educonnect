import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/homework/presentation/bloc/homework_bloc.dart';

class CreateHomeworkPage extends StatefulWidget {
  const CreateHomeworkPage({super.key});

  @override
  State<CreateHomeworkPage> createState() => _CreateHomeworkPageState();
}

class _CreateHomeworkPageState extends State<CreateHomeworkPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _instrCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController();
  final _courseIdCtrl = TextEditingController();
  final _attachmentCtrl = TextEditingController();

  DateTime? _dueDate;
  String _status = 'draft';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _instrCtrl.dispose();
    _maxScoreCtrl.dispose();
    _courseIdCtrl.dispose();
    _attachmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un devoir')),
      body: BlocListener<HomeworkBloc, HomeworkState>(
        listener: (context, state) {
          if (state is HomeworkCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Devoir créé avec succès !')),
            );
            Navigator.pop(context);
          }
          if (state is HomeworkError) {
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

                // Instructions
                TextFormField(
                  controller: _instrCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Instructions *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                SizedBox(height: 16.h),

                // Max score
                TextFormField(
                  controller: _maxScoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Note maximale *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (double.tryParse(v ?? '') ?? -1) <= 0
                      ? 'Note maximale requise'
                      : null,
                ),
                SizedBox(height: 16.h),

                // Due date picker
                InkWell(
                  onTap: _pickDueDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date limite *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _dueDate != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)
                          : 'Sélectionner une date',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: _dueDate != null ? null : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Attachment URL (optional)
                TextFormField(
                  controller: _attachmentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lien de pièce jointe (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_file),
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

                // Submit button
                BlocBuilder<HomeworkBloc, HomeworkState>(
                  builder: (context, state) {
                    final loading = state is HomeworkLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const CircularProgressIndicator()
                            : const Text('Créer'),
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _dueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date limite')),
      );
      return;
    }

    context.read<HomeworkBloc>().add(CreateHomeworkRequested(
          courseId: _courseIdCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          instructions: _instrCtrl.text.trim(),
          dueDate: _dueDate!.toUtc().toIso8601String(),
          maxScore: double.tryParse(_maxScoreCtrl.text) ?? 0,
          attachmentUrl: _attachmentCtrl.text.trim().isEmpty
              ? null
              : _attachmentCtrl.text.trim(),
          status: _status,
        ));
  }
}
