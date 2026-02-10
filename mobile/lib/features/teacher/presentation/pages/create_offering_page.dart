import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';

class CreateOfferingPage extends StatefulWidget {
  const CreateOfferingPage({super.key});

  @override
  State<CreateOfferingPage> createState() => _CreateOfferingPageState();
}

class _CreateOfferingPageState extends State<CreateOfferingPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectIdController = TextEditingController();
  final _levelIdController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxStudentsController = TextEditingController(text: '1');
  final _trialDurationController = TextEditingController(text: '0');

  String _sessionType = 'one_on_one';
  bool _freeTrialEnabled = false;

  @override
  void dispose() {
    _subjectIdController.dispose();
    _levelIdController.dispose();
    _priceController.dispose();
    _maxStudentsController.dispose();
    _trialDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle offre')),
      body: BlocListener<TeacherBloc, TeacherState>(
        listener: (context, state) {
          if (state is TeacherOfferingCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offre créée avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else if (state is TeacherError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<TeacherBloc, TeacherState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject ID
                    Text(
                      'ID de la matière',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _subjectIdController,
                      decoration: const InputDecoration(
                        hintText: 'UUID de la matière',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                    ),

                    SizedBox(height: 16.h),

                    // Level ID
                    Text(
                      'ID du niveau',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _levelIdController,
                      decoration: const InputDecoration(
                        hintText: 'UUID du niveau',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                    ),

                    SizedBox(height: 16.h),

                    // Session type
                    Text(
                      'Type de session',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      value: _sessionType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'one_on_one',
                          child: Text('Individuel'),
                        ),
                        DropdownMenuItem(
                          value: 'group',
                          child: Text('Groupe'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sessionType = v);
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Price
                    Text(
                      'Prix par heure (DA)',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 1500',
                        border: OutlineInputBorder(),
                        suffixText: 'DA',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requis';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),

                    if (_sessionType == 'group') ...[
                      SizedBox(height: 16.h),
                      Text(
                        'Nombre max d\'étudiants',
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8.h),
                      TextFormField(
                        controller: _maxStudentsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requis';
                          final n = int.tryParse(v);
                          if (n == null || n < 1 || n > 50) {
                            return 'Entre 1 et 50';
                          }
                          return null;
                        },
                      ),
                    ],

                    SizedBox(height: 16.h),

                    // Free trial
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Essai gratuit'),
                      subtitle: const Text(
                        'Permettre un premier cours d\'essai gratuit',
                      ),
                      value: _freeTrialEnabled,
                      onChanged: (v) => setState(() => _freeTrialEnabled = v),
                    ),

                    if (_freeTrialEnabled) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'Durée de l\'essai (minutes)',
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8.h),
                      TextFormField(
                        controller: _trialDurationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Ex: 30',
                          border: OutlineInputBorder(),
                          suffixText: 'min',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requis';
                          final n = int.tryParse(v);
                          if (n == null || n < 0 || n > 60) {
                            return 'Entre 0 et 60 min';
                          }
                          return null;
                        },
                      ),
                    ],

                    SizedBox(height: 32.h),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: state is TeacherLoading ? null : _submit,
                        child: state is TeacherLoading
                            ? SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Créer l\'offre'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<TeacherBloc>().add(
          TeacherOfferingCreateRequested(
            subjectId: _subjectIdController.text.trim(),
            levelId: _levelIdController.text.trim(),
            sessionType: _sessionType,
            pricePerHour: double.parse(_priceController.text.trim()),
            maxStudents: _sessionType == 'group'
                ? int.tryParse(_maxStudentsController.text.trim())
                : null,
            freeTrialEnabled: _freeTrialEnabled,
            freeTrialDuration: _freeTrialEnabled
                ? int.tryParse(_trialDurationController.text.trim()) ?? 0
                : 0,
          ),
        );
  }
}
