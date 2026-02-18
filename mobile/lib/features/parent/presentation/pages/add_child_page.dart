import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/core/constants/levels.dart';
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
  final _schoolCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  String? _selectedLevelCode;
  String? _selectedCycle;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _schoolCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  List<LevelItem> get _filteredLevels {
    if (_selectedCycle == null) return Levels.all;
    return Levels.byCycle(_selectedCycle!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un enfant')),
      body: BlocListener<ParentBloc, ParentState>(
        listener: (context, state) {
          if (state is ChildAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enfant ajouté avec succès !'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
          if (state is ParentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
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
                // Info card
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Un compte élève sera créé pour votre enfant. Vous pourrez suivre ses progrès et ses sessions.',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Name section
                Text(
                  'Informations de l\'enfant',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.length < 2) ? 'Min 2 caractères' : null,
                ),
                SizedBox(height: 16.h),

                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.length < 2) ? 'Min 2 caractères' : null,
                ),
                SizedBox(height: 24.h),

                // Education section
                Text(
                  'Scolarité',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                // Cycle filter
                DropdownButtonFormField<String>(
                  value: _selectedCycle,
                  decoration: const InputDecoration(
                    labelText: 'Cycle',
                    prefixIcon: Icon(Icons.school_outlined),
                    hintText: 'Tous les cycles',
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('Tous les cycles')),
                    DropdownMenuItem(
                        value: 'primaire', child: Text('Primaire')),
                    DropdownMenuItem(
                        value: 'moyen', child: Text('Moyen (CEM)')),
                    DropdownMenuItem(
                        value: 'secondaire', child: Text('Secondaire (Lycée)')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedCycle = v;
                      _selectedLevelCode =
                          null; // Reset level when cycle changes
                    });
                  },
                ),
                SizedBox(height: 16.h),

                // Level dropdown
                DropdownButtonFormField<String>(
                  value: _selectedLevelCode,
                  decoration: const InputDecoration(
                    labelText: 'Niveau *',
                    prefixIcon: Icon(Icons.grade_outlined),
                  ),
                  isExpanded: true,
                  items: _filteredLevels.map((level) {
                    return DropdownMenuItem(
                      value: level.code,
                      child: Text(
                        level.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedLevelCode = v),
                  validator: (v) => v == null ? 'Sélectionnez un niveau' : null,
                ),
                SizedBox(height: 16.h),

                TextFormField(
                  controller: _schoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'École (optionnel)',
                    prefixIcon: Icon(Icons.apartment_outlined),
                    hintText: 'Nom de l\'établissement',
                  ),
                ),
                SizedBox(height: 16.h),

                // Date of birth
                TextFormField(
                  controller: _dobCtrl,
                  decoration: InputDecoration(
                    labelText: 'Date de naissance (optionnel)',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    hintText: 'JJ/MM/AAAA',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickDate,
                    ),
                  ),
                  readOnly: true,
                  onTap: _pickDate,
                ),
                SizedBox(height: 32.h),

                // Submit button
                BlocBuilder<ParentBloc, ParentState>(
                  builder: (context, state) {
                    final loading = state is ParentLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _submit,
                        icon: loading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add),
                        label:
                            Text(loading ? 'Création...' : 'Ajouter l\'enfant'),
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10),
      firstDate: DateTime(now.year - 25),
      lastDate: DateTime(now.year - 3),
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLevelCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un niveau'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.read<ParentBloc>().add(AddChildRequested(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          levelCode: _selectedLevelCode!,
          filiere: null,
          school:
              _schoolCtrl.text.trim().isEmpty ? null : _schoolCtrl.text.trim(),
        ));
  }
}
