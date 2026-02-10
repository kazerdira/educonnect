import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:educonnect/features/session/presentation/bloc/session_bloc.dart';

class CreateSessionPage extends StatefulWidget {
  const CreateSessionPage({super.key});

  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _maxStudentsCtrl = TextEditingController(text: '1');
  final _offeringIdCtrl = TextEditingController();

  String _sessionType = 'individual';
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _offeringIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer une session')),
      body: BlocListener<SessionBloc, SessionState>(
        listener: (context, state) {
          if (state is SessionCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session créée avec succès !')),
            );
            Navigator.pop(context);
          }
          if (state is SessionError) {
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
                TextFormField(
                  controller: _offeringIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID de l\'offre',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),

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

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),

                DropdownButtonFormField<String>(
                  value: _sessionType,
                  items: const [
                    DropdownMenuItem(
                        value: 'individual', child: Text('Individuelle')),
                    DropdownMenuItem(value: 'group', child: Text('Groupe')),
                  ],
                  onChanged: (v) => setState(() => _sessionType = v!),
                  decoration: const InputDecoration(
                    labelText: 'Type de session *',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),

                // Date/time pickers
                _dateTile(
                  label: 'Début *',
                  value: _startTime,
                  onTap: () async {
                    final dt = await _pickDateTime();
                    if (dt != null) setState(() => _startTime = dt);
                  },
                ),
                SizedBox(height: 12.h),
                _dateTile(
                  label: 'Fin *',
                  value: _endTime,
                  onTap: () async {
                    final dt = await _pickDateTime();
                    if (dt != null) setState(() => _endTime = dt);
                  },
                ),
                SizedBox(height: 16.h),

                if (_sessionType == 'group') ...[
                  TextFormField(
                    controller: _maxStudentsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max étudiants *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 50) {
                        return 'Entre 1 et 50';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                ],

                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (DA) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Prix requis'
                      : null,
                ),
                SizedBox(height: 24.h),

                BlocBuilder<SessionBloc, SessionState>(
                  builder: (context, state) {
                    final loading = state is SessionLoading;
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

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(value)
              : 'Sélectionner',
          style: TextStyle(
            fontSize: 14.sp,
            color: value != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez les dates')),
      );
      return;
    }

    context.read<SessionBloc>().add(CreateSessionRequested(
          offeringId: _offeringIdCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          sessionType: _sessionType,
          startTime: _startTime!.toUtc().toIso8601String(),
          endTime: _endTime!.toUtc().toIso8601String(),
          maxStudents: int.tryParse(_maxStudentsCtrl.text) ?? 1,
          price: double.tryParse(_priceCtrl.text) ?? 0,
        ));
  }
}
