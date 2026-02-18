import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/booking_request.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import 'booking_conversation_page.dart';

/// Page for students to view their booking requests.
class StudentBookingsPage extends StatefulWidget {
  const StudentBookingsPage({super.key});

  @override
  State<StudentBookingsPage> createState() => _StudentBookingsPageState();
}

class _StudentBookingsPageState extends State<StudentBookingsPage> {
  late final BookingBloc _bookingBloc;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _bookingBloc = getIt<BookingBloc>();
    _loadBookings();
  }

  void _loadBookings() {
    _bookingBloc.add(LoadBookingsRequested(
      role: 'as_student',
      status: _selectedStatus,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bookingBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes demandes'),
          actions: [
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              onSelected: (v) {
                setState(() => _selectedStatus = v);
                _loadBookings();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: null, child: Text('Toutes')),
                const PopupMenuItem(
                    value: 'pending', child: Text('En attente')),
                const PopupMenuItem(
                    value: 'accepted', child: Text('Acceptées')),
                const PopupMenuItem(value: 'declined', child: Text('Refusées')),
              ],
            ),
          ],
        ),
        body: BlocConsumer<BookingBloc, BookingState>(
          listener: (ctx, state) {
            if (state is BookingCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demande annulée'),
                  backgroundColor: Colors.orange,
                ),
              );
              _loadBookings();
            } else if (state is BookingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
              _loadBookings();
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
                onRefresh: () async => _loadBookings(),
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
          Icon(Icons.calendar_today_outlined,
              size: 64.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'Aucune demande de séance',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
          ),
          SizedBox(height: 8.h),
          Text(
            'Trouvez un enseignant et réservez!',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
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
                    booking.teacherName.isNotEmpty
                        ? booking.teacherName[0].toUpperCase()
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
                        booking.teacherName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (booking.subjectName.isNotEmpty ||
                          booking.levelName.isNotEmpty)
                        Text(
                          [
                            if (booking.subjectName.isNotEmpty)
                              booking.subjectName,
                            if (booking.levelName.isNotEmpty) booking.levelName,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '${booking.formattedDate} · ${booking.formattedTime}',
                        style:
                            TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
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

            // Chat + Cancel for pending bookings
            if (isPending) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openConversation(booking),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Discuter'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmCancel(booking.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ],

            // Chat link for non-pending bookings
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

  void _confirmCancel(String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande?'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette demande de séance?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bookingBloc.add(CancelBookingRequested(bookingId: bookingId));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}
