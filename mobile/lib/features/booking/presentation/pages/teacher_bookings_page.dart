import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/booking_request.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import 'booking_conversation_page.dart';

/// Page for teachers to manage booking requests from students.
class TeacherBookingsPage extends StatefulWidget {
  const TeacherBookingsPage({super.key});

  @override
  State<TeacherBookingsPage> createState() => _TeacherBookingsPageState();
}

class _TeacherBookingsPageState extends State<TeacherBookingsPage>
    with SingleTickerProviderStateMixin {
  late final BookingBloc _bookingBloc;
  late final TabController _tabController;

  final _statusFilters = ['pending', 'accepted', 'declined'];

  @override
  void initState() {
    super.initState();
    _bookingBloc = getIt<BookingBloc>();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings('pending');
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadBookings(_statusFilters[_tabController.index]);
      }
    });
  }

  void _loadBookings(String status) {
    _bookingBloc.add(LoadBookingsRequested(role: 'as_teacher', status: status));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bookingBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demandes de séances'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'En attente'),
              Tab(text: 'Acceptées'),
              Tab(text: 'Refusées'),
            ],
          ),
        ),
        body: BlocConsumer<BookingBloc, BookingState>(
          listener: (ctx, state) {
            if (state is BookingAccepted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.booking.sessionType == 'group'
                        ? 'Demande acceptée ✓ Élève ajouté à la séance'
                        : 'Demande acceptée ✓ Séance créée',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
              _loadBookings(_statusFilters[_tabController.index]);
            } else if (state is BookingDeclined) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demande refusée'),
                  backgroundColor: Colors.orange,
                ),
              );
              _loadBookings(_statusFilters[_tabController.index]);
            } else if (state is BookingError) {
              _showConflictDialog(state.message);
              _loadBookings(_statusFilters[_tabController.index]);
            }
          },
          buildWhen: (prev, curr) =>
              curr is BookingLoading || curr is BookingListLoaded,
          builder: (ctx, state) {
            if (state is BookingLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is BookingListLoaded) {
              if (state.bookings.isEmpty) {
                return _emptyState();
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    _loadBookings(_statusFilters[_tabController.index]),
                child: ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: state.bookings.length,
                  itemBuilder: (ctx, i) => _bookingCard(state.bookings[i]),
                ),
              );
            }

            return _emptyState();
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'Aucune demande',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(BookingRequest booking) {
    final theme = Theme.of(context);
    final isPending = booking.status == BookingStatus.pending;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    booking.studentName.isNotEmpty
                        ? booking.studentName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.studentName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (booking.isParentBooking &&
                          booking.bookedByParentName != null) ...[
                        Row(
                          children: [
                            Icon(Icons.family_restroom,
                                size: 12.sp,
                                color: theme.colorScheme.secondary),
                            SizedBox(width: 4.w),
                            Text(
                              'Réservé par ${booking.bookedByParentName}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Text(
                        booking.formattedDate,
                        style:
                            TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _statusChip(booking.status),
              ],
            ),

            SizedBox(height: 12.h),
            Divider(height: 1, color: Colors.grey[200]),
            SizedBox(height: 12.h),

            // Details
            _detailRow(
              booking.sessionType == 'group' ? Icons.groups : Icons.person,
              'Type',
              booking.sessionType == 'group' ? 'Groupe' : 'Individuel',
            ),
            if (booking.purpose.isNotEmpty)
              _detailRow(Icons.flag, 'Objectif', booking.purpose),
            if (booking.message.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Message:',
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                    SizedBox(height: 4.h),
                    Text(booking.message, style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
            ],

            if (booking.declineReason != null &&
                booking.declineReason!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raison du refus:',
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700])),
                    SizedBox(height: 4.h),
                    Text(booking.declineReason!,
                        style:
                            TextStyle(fontSize: 13.sp, color: Colors.red[800])),
                  ],
                ),
              ),
            ],

            // Actions for pending bookings
            if (isPending) ...[
              SizedBox(height: 16.h),
              Row(
                children: [
                  // Chat / Discuss button
                  IconButton(
                    onPressed: () => _openConversation(booking),
                    icon: Icon(Icons.chat_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    tooltip: 'Discuter',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 110.w,
                    child: OutlinedButton(
                      onPressed: () => _showDeclineDialog(booking.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  SizedBox(
                    width: 110.w,
                    child: ElevatedButton(
                      onPressed: () => _showAcceptDialog(booking),
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
            ],

            // Chat button for non-pending bookings too
            if (!isPending) ...[
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openConversation(booking),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Voir la conversation'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey[500]),
          SizedBox(width: 8.w),
          Text('$label: ',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 13.sp)),
        ],
      ),
    );
  }

  Widget _statusChip(BookingStatus status) {
    Color color;
    String label;
    switch (status) {
      case BookingStatus.pending:
        color = Colors.orange;
        label = 'En attente';
        break;
      case BookingStatus.accepted:
        color = Colors.green;
        label = 'Acceptée';
        break;
      case BookingStatus.declined:
        color = Colors.red;
        label = 'Refusée';
        break;
      case BookingStatus.cancelled:
        color = Colors.grey;
        label = 'Annulée';
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _openConversation(BookingRequest booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConversationPage(booking: booking),
      ),
    );
  }

  void _showConflictDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.event_busy, size: 40.sp, color: Colors.orange[700]),
        title: const Text('Créneau non disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, height: 1.4),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_outlined,
                      size: 20.sp, color: Colors.blue[700]),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Utilisez la messagerie pour proposer un autre horaire à l\'élève.',
                      style:
                          TextStyle(fontSize: 12.sp, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
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

  void _showAcceptDialog(BookingRequest booking) {
    final titleController =
        TextEditingController(text: 'Séance du ${booking.formattedDate}');
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isGroup = booking.sessionType == 'group';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accepter la demande'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auto-merge info for group bookings
                if (isGroup) ...[
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18.sp, color: Colors.blue[700]),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Si vous avez déjà une séance de groupe à cet horaire, '
                            'l\'élève sera automatiquement ajouté à cette séance.',
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.blue[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Titre de la séance',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Prix (DA)',
                    hintText: 'Ex: 2000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Le prix est obligatoire';
                    }
                    final price = double.tryParse(v);
                    if (price == null || price < 0) {
                      return 'Entrez un prix valide';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              _bookingBloc.add(AcceptBookingRequested(
                bookingId: booking.id,
                title: titleController.text.isNotEmpty
                    ? titleController.text
                    : null,
                price: double.tryParse(priceController.text) ?? 0,
              ));
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog(String bookingId) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la demande'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Raison du refus',
              hintText: 'Ex: Indisponible ce jour-là...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 5) {
                return 'Veuillez préciser la raison (min. 5 caractères)';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              _bookingBloc.add(DeclineBookingRequested(
                bookingId: bookingId,
                reason: reasonController.text.trim(),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }
}
