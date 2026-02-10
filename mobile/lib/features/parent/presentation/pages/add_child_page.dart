import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';

class AddChildPage extends StatefulWidget {
  const AddChildPage({super.key});

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _levelCodeCtrl = TextEditingController();
  final _filiereCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _levelCodeCtrl.dispose();
    _filiereCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un enfant')),
      body: BlocListener<ParentBloc, ParentState>(
        listener: (context, state) {
          if (state is ChildAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enfant ajouté avec succès !')),
            );
            Navigator.pop(context);
          }
          if (state is ParentError) {
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
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 2) ? 'Min 2 caractères' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 2) ? 'Min 2 caractères' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _levelCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code niveau * (ex: 3AS)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _filiereCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Filière (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _schoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'École (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 24.h),
                BlocBuilder<ParentBloc, ParentState>(
                  builder: (context, state) {
                    final loading = state is ParentLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const CircularProgressIndicator()
                            : const Text('Ajouter'),
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
    context.read<ParentBloc>().add(AddChildRequested(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          levelCode: _levelCodeCtrl.text.trim(),
          filiere: _filiereCtrl.text.trim().isEmpty
              ? null
              : _filiereCtrl.text.trim(),
          school:
              _schoolCtrl.text.trim().isEmpty ? null : _schoolCtrl.text.trim(),
        ));
  }
}
