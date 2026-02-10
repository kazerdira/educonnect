import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/course/presentation/bloc/course_bloc.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _isPublished = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un cours')),
      body: BlocListener<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cours créé avec succès !')),
            );
            Navigator.pop(context);
          }
          if (state is CourseError) {
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
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (DA) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0
                      ? 'Prix requis'
                      : null,
                ),
                SizedBox(height: 16.h),
                SwitchListTile(
                  title: const Text('Publier maintenant'),
                  value: _isPublished,
                  onChanged: (v) => setState(() => _isPublished = v),
                ),
                SizedBox(height: 24.h),
                BlocBuilder<CourseBloc, CourseState>(
                  builder: (context, state) {
                    final loading = state is CourseLoading;
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CourseBloc>().add(CreateCourseRequested(
          title: _titleCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          price: double.tryParse(_priceCtrl.text) ?? 0,
          isPublished: _isPublished,
        ));
  }
}
