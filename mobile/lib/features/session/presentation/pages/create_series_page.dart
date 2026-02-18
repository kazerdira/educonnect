import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/core/constants/levels.dart';
import 'package:educonnect/core/constants/subjects.dart';
import 'package:educonnect/features/session/presentation/bloc/series_bloc.dart';

class CreateSeriesPage extends StatelessWidget {
  const CreateSeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SeriesBloc>(),
      child: const _CreateSeriesForm(),
    );
  }
}

class _CreateSeriesForm extends StatefulWidget {
  const _CreateSeriesForm();

  @override
  State<_CreateSeriesForm> createState() => _CreateSeriesFormState();
}

class _CreateSeriesFormState extends State<_CreateSeriesForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  String? _selectedLevelId;
  String? _selectedSubjectId;
  String _sessionType = 'one_on_one';
  double _durationHours = 1.0;
  int _minStudents = 1;
  int _maxStudents = 1;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onSessionTypeChanged(String? value) {
    if (value != null) {
      setState(() {
        _sessionType = value;
        if (value == 'one_on_one') {
          _minStudents = 1;
          _maxStudents = 1;
        } else {
          _minStudents = 2;
          _maxStudents = 10;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLevelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un niveau'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une matière'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.read<SeriesBloc>().add(CreateSeriesRequested(
          levelId: _selectedLevelId,
          subjectId: _selectedSubjectId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          sessionType: _sessionType,
          durationHours: _durationHours,
          minStudents: _minStudents,
          maxStudents: _maxStudents,
          pricePerHour: double.tryParse(_priceController.text) ?? 0.0,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<SeriesBloc, SeriesState>(
      listener: (context, state) {
        if (state is SeriesCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Série créée avec succès!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to series detail to add sessions
          context.go('/teacher/series/${state.series.id}');
        } else if (state is SeriesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nouvelle Série'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // Info card
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'Une série vous permet de planifier plusieurs sessions avec les mêmes élèves (ex: cours hebdomadaires).',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la série *',
                  hintText: 'Ex: Maths 3AM - Février',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Le titre est requis'
                    : null,
              ),
              SizedBox(height: 16.h),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  hintText: 'Décrivez le contenu des sessions...',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24.h),

              // Level Selection
              Text(
                'Niveau *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                value: _selectedLevelId,
                decoration: const InputDecoration(
                  hintText: 'Sélectionnez un niveau',
                  prefixIcon: Icon(Icons.school),
                ),
                isExpanded: true,
                items: Levels.all.map((level) {
                  return DropdownMenuItem(
                    value: level.code,
                    child: Text(
                      level.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLevelId = value);
                },
              ),
              SizedBox(height: 16.h),

              // Subject Selection
              Text(
                'Matière *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                value: _selectedSubjectId,
                decoration: const InputDecoration(
                  hintText: 'Sélectionnez une matière',
                  prefixIcon: Icon(Icons.book),
                ),
                isExpanded: true,
                items: Subjects.all.map((subject) {
                  return DropdownMenuItem(
                    value: subject.id,
                    child: Text(
                      subject.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedSubjectId = value);
                },
              ),
              SizedBox(height: 24.h),

              // Session Type
              Text(
                'Type de session',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _TypeOption(
                      icon: Icons.person,
                      label: 'Individuel',
                      subtitle: '1 élève',
                      isSelected: _sessionType == 'one_on_one',
                      onTap: () => _onSessionTypeChanged('one_on_one'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _TypeOption(
                      icon: Icons.groups,
                      label: 'Groupe',
                      subtitle: '2-20 élèves',
                      isSelected: _sessionType == 'group',
                      onTap: () => _onSessionTypeChanged('group'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Duration
              Text(
                'Durée par session',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              _DurationSelector(
                value: _durationHours,
                onChanged: (v) => setState(() => _durationHours = v),
              ),
              SizedBox(height: 24.h),

              // Max Students (for group)
              if (_sessionType == 'group') ...[
                Text(
                  'Nombre d\'élèves',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minimum',
                            style: theme.textTheme.bodySmall,
                          ),
                          SizedBox(height: 4.h),
                          _CounterField(
                            value: _minStudents,
                            min: 2,
                            max: 20,
                            onChanged: (v) {
                              setState(() {
                                _minStudents = v;
                                if (_maxStudents < v) _maxStudents = v;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Maximum',
                            style: theme.textTheme.bodySmall,
                          ),
                          SizedBox(height: 4.h),
                          _CounterField(
                            value: _maxStudents,
                            min: _minStudents,
                            max: 20,
                            onChanged: (v) => setState(() => _maxStudents = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
              ],

              // Price per hour
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prix par heure (DA)',
                  hintText: '0 = gratuit',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: 'DA',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16.h),

              // Platform fee info
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20.sp,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Frais de plateforme',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        _sessionType == 'group'
                            ? '• 50 DA/élève/heure pour les sessions de groupe'
                            : '• 120 DA/heure pour les sessions individuelles',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '• Les frais seront calculés après finalisation',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Submit button
              BlocBuilder<SeriesBloc, SeriesState>(
                builder: (context, state) {
                  final isLoading = state is SeriesLoading;
                  return FilledButton.icon(
                    onPressed: isLoading ? null : _submit,
                    icon: isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(isLoading ? 'Création...' : 'Créer la série'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32.sp,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              SizedBox(height: 8.h),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DurationSelector({required this.value, required this.onChanged});

  static const _durations = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _durations.map((d) {
        final isSelected = value == d;
        return ChoiceChip(
          label: Text('${d}h'),
          selected: isSelected,
          onSelected: (_) => onChanged(d),
          selectedColor: theme.colorScheme.primaryContainer,
        );
      }).toList(),
    );
  }
}

class _CounterField extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CounterField({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            iconSize: 20.sp,
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            iconSize: 20.sp,
          ),
        ],
      ),
    );
  }
}
