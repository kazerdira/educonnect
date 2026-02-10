import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';

class TeacherProfileEditPage extends StatefulWidget {
  const TeacherProfileEditPage({super.key});

  @override
  State<TeacherProfileEditPage> createState() => _TeacherProfileEditPageState();
}

class _TeacherProfileEditPageState extends State<TeacherProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specController = TextEditingController();
  List<String> _specializations = [];

  bool _initialized = false;

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    _specController.dispose();
    super.dispose();
  }

  void _initFromDashboard() {
    if (_initialized) return;
    final teacherState = context.read<TeacherBloc>().state;
    if (teacherState is TeacherDashboardLoaded) {
      final p = teacherState.dashboard.profile;
      _bioController.text = p.bio;
      _experienceController.text =
          p.experienceYears > 0 ? p.experienceYears.toString() : '';
      _specializations = List<String>.from(p.specializations);
      _initialized = true;
    } else if (teacherState is TeacherProfileLoaded) {
      final p = teacherState.profile;
      _bioController.text = p.bio;
      _experienceController.text =
          p.experienceYears > 0 ? p.experienceYears.toString() : '';
      _specializations = List<String>.from(p.specializations);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromDashboard();

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: BlocListener<TeacherBloc, TeacherState>(
        listener: (context, state) {
          if (state is TeacherProfileUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil mis à jour avec succès'),
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
                    // Bio
                    Text(
                      'Biographie',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText:
                            'Décrivez votre parcours, vos méthodes d\'enseignement...',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Experience
                    Text(
                      'Années d\'expérience',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 5',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final n = int.tryParse(v);
                          if (n == null || n < 0 || n > 50) {
                            return 'Entre 0 et 50';
                          }
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Specializations
                    Text(
                      'Spécialisations',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        ..._specializations.map(
                          (s) => Chip(
                            label: Text(s),
                            onDeleted: () {
                              setState(() => _specializations.remove(s));
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _specController,
                            decoration: const InputDecoration(
                              hintText: 'Ajouter une spécialisation',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onFieldSubmitted: (_) => _addSpecialization(),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          onPressed: _addSpecialization,
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),

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
                            : const Text('Enregistrer'),
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

  void _addSpecialization() {
    final text = _specController.text.trim();
    if (text.isNotEmpty && !_specializations.contains(text)) {
      setState(() {
        _specializations.add(text);
        _specController.clear();
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final expText = _experienceController.text.trim();

    context.read<TeacherBloc>().add(
          TeacherProfileUpdateRequested(
            bio: _bioController.text.trim(),
            experienceYears: expText.isNotEmpty ? int.tryParse(expText) : null,
            specializations:
                _specializations.isNotEmpty ? _specializations : null,
          ),
        );
  }
}
