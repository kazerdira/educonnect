import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/teacher/domain/entities/availability_slot.dart';

class TeacherAvailabilityPage extends StatefulWidget {
  const TeacherAvailabilityPage({super.key});

  @override
  State<TeacherAvailabilityPage> createState() =>
      _TeacherAvailabilityPageState();
}

class _TeacherAvailabilityPageState extends State<TeacherAvailabilityPage> {
  List<_EditableSlot> _slots = [];
  bool _loaded = false;

  static const _dayNames = [
    'Dimanche',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
  ];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<TeacherBloc>().add(
            TeacherAvailabilityRequested(teacherId: authState.user.id),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilité'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'availability_fab',
        onPressed: _addSlot,
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<TeacherBloc, TeacherState>(
        listener: (context, state) {
          if (state is TeacherAvailabilityLoaded && !_loaded) {
            setState(() {
              _slots = state.slots
                  .map((s) => _EditableSlot(
                        dayOfWeek: s.dayOfWeek,
                        startTime: s.startTime,
                        endTime: s.endTime,
                      ))
                  .toList();
              _loaded = true;
            });
          } else if (state is TeacherAvailabilityLoaded && _loaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Disponibilité mise à jour'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TeacherError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TeacherLoading && !_loaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_slots.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 64.sp, color: Colors.grey[400]),
                  SizedBox(height: 12.h),
                  Text(
                    'Aucun créneau défini',
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Appuyez sur + pour ajouter un créneau',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          // Group by day
          final grouped = <int, List<int>>{};
          for (var i = 0; i < _slots.length; i++) {
            grouped.putIfAbsent(_slots[i].dayOfWeek, () => []).add(i);
          }
          final sortedDays = grouped.keys.toList()..sort();

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              for (final day in sortedDays) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    _dayNames[day],
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                ...grouped[day]!.map((idx) => _slotCard(idx, theme)),
              ],
              SizedBox(height: 80.h), // space for FAB
            ],
          );
        },
      ),
    );
  }

  Widget _slotCard(int index, ThemeData theme) {
    final slot = _slots[index];
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _timePicker(
                    label: 'Début',
                    value: slot.startTime,
                    onChanged: (v) =>
                        setState(() => _slots[index].startTime = v),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Icon(Icons.arrow_forward, size: 16.sp),
                  ),
                  _timePicker(
                    label: 'Fin',
                    value: slot.endTime,
                    onChanged: (v) => setState(() => _slots[index].endTime = v),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _slots.removeAt(index)),
              icon: Icon(Icons.delete_outline, color: Colors.red, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) {
          onChanged(
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          value.isEmpty ? label : value,
          style: TextStyle(fontSize: 14.sp),
        ),
      ),
    );
  }

  void _addSlot() {
    showDialog(
      context: context,
      builder: (ctx) {
        int selectedDay = 1; // Monday
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Ajouter un créneau'),
            content: DropdownButtonFormField<int>(
              value: selectedDay,
              decoration: const InputDecoration(
                labelText: 'Jour',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                7,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(_dayNames[i]),
                ),
              ),
              onChanged: (v) {
                if (v != null) setDialogState(() => selectedDay = v);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _slots.add(_EditableSlot(
                      dayOfWeek: selectedDay,
                      startTime: '08:00',
                      endTime: '10:00',
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save() {
    final slots = _slots
        .map((s) => AvailabilitySlot(
              id: '',
              dayOfWeek: s.dayOfWeek,
              startTime: s.startTime,
              endTime: s.endTime,
            ))
        .toList();

    context.read<TeacherBloc>().add(
          TeacherAvailabilityUpdateRequested(slots: slots),
        );
  }
}

class _EditableSlot {
  int dayOfWeek;
  String startTime;
  String endTime;

  _EditableSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });
}
