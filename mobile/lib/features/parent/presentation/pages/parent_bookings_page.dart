import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/injection.dart';
import '../../../booking/domain/entities/booking_request.dart';
import '../../../booking/presentation/bloc/booking_bloc.dart';
import '../../../booking/presentation/bloc/booking_event.dart';
import '../../../booking/presentation/bloc/booking_state.dart';
import '../../../booking/presentation/pages/booking_conversation_page.dart';

/// Page for parents to view booking requests made on behalf of their children.
class ParentBookingsPage extends StatefulWidget {
  const ParentBookingsPage({super.key});

  @override
  State<ParentBookingsPage> createState() => _ParentBookingsPageState();
}

class _ParentBookingsPageState extends State<ParentBookingsPage> {
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
      role: 'as_parent',
      status: _selectedStatus,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bookingBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réservations des enfants'),
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
          Icon(Icons.inbox_outlined, size: 64.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'Aucune réservation',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
          ),
          SizedBox(height: 8.h),
          Text(
            'Les réservations faites pour vos\nenfants apparaîtront ici',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
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
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 12.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text(
                            booking.teacherName,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (booking.subjectName.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            [
                              booking.subjectName,
                              if (booking.levelName.isNotEmpty)
                                booking.levelName,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          '${booking.formattedDate} · ${booking.formattedTime}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[500],
                          ),
                        ),
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
            _detailRow(Icons.group, 'Type',
                booking.sessionType == 'group' ? 'Groupe' : 'Individuel'),
            if (booking.purpose.isNotEmpty)
              _detailRow(Icons.flag, 'Objectif', booking.purpose),

            // Chat + Cancel for pending
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
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Annuler'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _confirmCancel(booking.id),
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

            // Decline reason if declined
            if (booking.status == BookingStatus.declined &&
                booking.declineReason != null &&
                booking.declineReason!.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.red[300], size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        booking.declineReason!,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BookingStatus status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case BookingStatus.pending:
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        label = 'En attente';
        icon = Icons.schedule;
        break;
      case BookingStatus.accepted:
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        label = 'Acceptée';
        icon = Icons.check_circle;
        break;
      case BookingStatus.declined:
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        label = 'Refusée';
        icon = Icons.cancel;
        break;
      case BookingStatus.cancelled:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = 'Annulée';
        icon = Icons.block;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey[500]),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
            ),
          ),
        ],
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
            'Êtes-vous sûr de vouloir annuler cette demande de réservation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _bookingBloc.add(CancelBookingRequested(bookingId: bookingId));
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}
