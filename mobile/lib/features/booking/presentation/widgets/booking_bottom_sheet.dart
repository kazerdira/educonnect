import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/injection.dart';
import '../../../teacher/domain/entities/offering.dart';
import '../../../teacher/domain/entities/availability_slot.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';

/// Bottom sheet for booking a session with a teacher.
class BookingBottomSheet extends StatefulWidget {
  const BookingBottomSheet({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.offerings,
    required this.availability,
    this.forChildId,
    this.forChildName,
  });

  final String teacherId;
  final String teacherName;
  final List<Offering> offerings;
  final List<AvailabilitySlot> availability;

  /// If booking as a parent for a child, provide the child's user ID
  final String? forChildId;

  /// Child name for display purposes
  final String? forChildName;

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  late final BookingBloc _bookingBloc;

  Offering? _selectedOffering;
  String _sessionType = 'individual';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  final _messageController = TextEditingController();
  final _purposeController = TextEditingController();

  final List<String> _purposeOptions = [
    'Préparation aux examens',
    'Rattrapage scolaire',
    'Soutien régulier',
    'Orientation',
    'Aide aux devoirs',
    'Autre',
  ];
  String? _selectedPurpose;

  @override
  void initState() {
    super.initState();
    _bookingBloc = getIt<BookingBloc>();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  List<AvailabilitySlot> get _slotsForSelectedDate {
    final dayOfWeek = _selectedDate.weekday % 7; // Convert to 0=Sunday format
    return widget.availability.where((s) => s.dayOfWeek == dayOfWeek).toList();
  }

  bool get _isFormValid {
    return _selectedStartTime != null &&
        _selectedEndTime != null &&
        (_selectedPurpose != null || _purposeController.text.isNotEmpty);
  }

  void _submit() {
    if (!_isFormValid) return;

    final startTime =
        '${_selectedStartTime!.hour.toString().padLeft(2, '0')}:${_selectedStartTime!.minute.toString().padLeft(2, '0')}';
    final endTime =
        '${_selectedEndTime!.hour.toString().padLeft(2, '0')}:${_selectedEndTime!.minute.toString().padLeft(2, '0')}';

    _bookingBloc.add(CreateBookingRequested(
      teacherId: widget.teacherId,
      offeringId: _selectedOffering?.id,
      sessionType: _sessionType,
      requestedDate: _selectedDate,
      startTime: startTime,
      endTime: endTime,
      message:
          _messageController.text.isNotEmpty ? _messageController.text : null,
      purpose: _selectedPurpose ?? _purposeController.text,
      forChildId: widget.forChildId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider.value(
      value: _bookingBloc,
      child: BlocListener<BookingBloc, BookingState>(
        listener: (ctx, state) {
          if (state is BookingCreateSuccess) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Demande envoyée à ${widget.teacherName}'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is BookingError) {
            _showBookingErrorDialog(context, state.message);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Réserver une séance',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'avec ${widget.teacherName}',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                if (widget.forChildName != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.child_care,
                            size: 16.sp,
                            color: theme.colorScheme.onPrimaryContainer),
                        SizedBox(width: 4.w),
                        Text(
                          'Pour ${widget.forChildName}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 20.h),

                // Offering selector (optional)
                if (widget.offerings.isNotEmpty) ...[
                  Text('Matière (optionnel)',
                      style: theme.textTheme.titleSmall),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<Offering?>(
                    value: _selectedOffering,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Sélectionner une matière',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                    items: [
                      const DropdownMenuItem<Offering?>(
                        value: null,
                        child: Text('Aucune préférence'),
                      ),
                      ...widget.offerings
                          .map((o) => DropdownMenuItem<Offering?>(
                                value: o,
                                child: Text(
                                    '${o.subjectName} - ${o.levelName} (${o.pricePerHour.toStringAsFixed(0)} DA/h)',
                                    overflow: TextOverflow.ellipsis),
                              )),
                    ],
                    onChanged: (v) => setState(() => _selectedOffering = v),
                  ),
                  SizedBox(height: 16.h),
                ],

                // Session type
                Text('Type de séance', style: theme.textTheme.titleSmall),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _typeButton(
                        icon: Icons.person,
                        label: 'Individuel',
                        value: 'individual',
                        theme: theme,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _typeButton(
                        icon: Icons.groups,
                        label: 'Groupe',
                        value: 'group',
                        theme: theme,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Date picker
                Text('Date souhaitée', style: theme.textTheme.titleSmall),
                SizedBox(height: 8.h),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20.sp, color: theme.colorScheme.primary),
                        SizedBox(width: 12.w),
                        Text(_formatDate(_selectedDate),
                            style: TextStyle(fontSize: 15.sp)),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            size: 20.sp, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Availability info
                if (_slotsForSelectedDate.isEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.orange[700], size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Aucune disponibilité ce jour. L\'enseignant décidera.',
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green[700], size: 18.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Créneaux disponibles:',
                              style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[800]),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        ...(_slotsForSelectedDate.map((s) => Padding(
                              padding: EdgeInsets.only(left: 26.w, top: 2.h),
                              child: Text(
                                '${s.startTime} - ${s.endTime}',
                                style: TextStyle(fontSize: 13.sp),
                              ),
                            ))),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 16.h),

                // Time selectors
                Text('Horaire souhaité', style: theme.textTheme.titleSmall),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        label: 'Début',
                        value: _selectedStartTime,
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _timePicker(
                        label: 'Fin',
                        value: _selectedEndTime,
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Purpose
                Text('Objectif de la séance',
                    style: theme.textTheme.titleSmall),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _purposeOptions.map((p) {
                    final selected = _selectedPurpose == p;
                    return FilterChip(
                      label: Text(p),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          _selectedPurpose = v ? p : null;
                          if (v) _purposeController.clear();
                        });
                      },
                    );
                  }).toList(),
                ),
                if (_selectedPurpose == 'Autre') ...[
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _purposeController,
                    decoration: InputDecoration(
                      hintText: 'Précisez...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ],
                SizedBox(height: 16.h),

                // Message
                Text('Message (optionnel)', style: theme.textTheme.titleSmall),
                SizedBox(height: 8.h),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Bonjour, je souhaite...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 24.h),

                // Submit button
                BlocBuilder<BookingBloc, BookingState>(
                  builder: (ctx, state) {
                    final loading = state is BookingLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton.icon(
                        onPressed: loading || !_isFormValid ? null : _submit,
                        icon: loading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                        label: Text(loading
                            ? 'Envoi en cours...'
                            : 'Envoyer la demande'),
                      ),
                    );
                  },
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    final selected = _sessionType == value;
    return InkWell(
      onTap: () => setState(() => _sessionType = value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color:
              selected ? theme.colorScheme.primaryContainer : Colors.grey[100],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20.sp,
                color: selected ? theme.colorScheme.primary : Colors.grey[600]),
            SizedBox(width: 8.w),
            Text(label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      selected ? theme.colorScheme.primary : Colors.grey[700],
                )),
          ],
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18.sp, color: Colors.grey[600]),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
                Text(
                  value != null ? value.format(context) : '-- : --',
                  style: TextStyle(fontSize: 15.sp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_selectedStartTime ?? const TimeOfDay(hour: 18, minute: 0))
          : (_selectedEndTime ?? const TimeOfDay(hour: 19, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = picked;
          // Auto-set end time 1 hour later
          if (_selectedEndTime == null) {
            _selectedEndTime = TimeOfDay(
              hour: (picked.hour + 1) % 24,
              minute: picked.minute,
            );
          }
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    final days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${days[date.weekday % 7]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showBookingErrorDialog(BuildContext ctx, String message) {
    final theme = Theme.of(ctx);
    final isAvailabilityError =
        message.contains('disponibilité') || message.contains('Créneaux');

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(
              isAvailabilityError
                  ? Icons.schedule_rounded
                  : Icons.error_outline_rounded,
              color: isAvailabilityError ? Colors.orange : Colors.red,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                isAvailabilityError ? 'Créneau non disponible' : 'Erreur',
                style: TextStyle(fontSize: 17.sp),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 14.sp, height: 1.4),
            ),
            if (isAvailabilityError) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18.sp, color: theme.colorScheme.primary),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Choisissez un horaire parmi les créneaux ci-dessus.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}
