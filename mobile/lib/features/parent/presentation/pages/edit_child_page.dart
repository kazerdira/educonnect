import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/parent/domain/entities/child.dart' as ent;
import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';

class EditChildPage extends StatefulWidget {
  final ent.Child child;

  const EditChildPage({super.key, required this.child});

  @override
  State<EditChildPage> createState() => _EditChildPageState();
}

class _EditChildPageState extends State<EditChildPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _levelCodeCtrl;
  late final TextEditingController _filiereCtrl;
  late final TextEditingController _schoolCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.child.firstName);
    _lastNameCtrl = TextEditingController(text: widget.child.lastName);
    _levelCodeCtrl = TextEditingController(text: widget.child.levelCode ?? '');
    _filiereCtrl = TextEditingController(text: widget.child.filiere ?? '');
    _schoolCtrl = TextEditingController(text: widget.child.school ?? '');
  }

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
      appBar: AppBar(title: const Text('Modifier l\'enfant')),
      body: BlocListener<ParentBloc, ParentState>(
        listener: (context, state) {
          if (state is ChildUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enfant mis à jour !')),
            );
            context.pop();
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
                            : const Text('Enregistrer'),
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
    context.read<ParentBloc>().add(UpdateChildRequested(
          childId: widget.child.id,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          levelCode: _levelCodeCtrl.text.trim(),
          school:
              _schoolCtrl.text.trim().isEmpty ? null : _schoolCtrl.text.trim(),
        ));
  }
}
