import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/booking_message.dart';
import '../../domain/entities/booking_request.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';

/// Full-screen WhatsApp-style chat for a booking conversation.
class BookingConversationPage extends StatefulWidget {
  final BookingRequest booking;

  const BookingConversationPage({super.key, required this.booking});

  @override
  State<BookingConversationPage> createState() =>
      _BookingConversationPageState();
}

class _BookingConversationPageState extends State<BookingConversationPage>
    with TickerProviderStateMixin {
  late final BookingBloc _chatBloc;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<BookingMessage> _messages = [];
  String? _currentUserId;
  bool _initialLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chatBloc = getIt<BookingBloc>();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
    }

    _chatBloc.add(LoadMessagesRequested(bookingId: widget.booking.id));

    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _chatBloc.add(LoadMessagesRequested(bookingId: widget.booking.id));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _chatBloc.add(SendMessageRequested(
      bookingId: widget.booking.id,
      content: text,
    ));
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return "Aujourd'hui";
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    const months = [
      '',
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'jun',
      'jul',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _timeLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = widget.booking.status == BookingStatus.pending;
    final b = widget.booking;

    // Determine partner name & initial
    final isTeacher = _currentUserId == b.teacherId;
    final partnerName = isTeacher ? b.studentName : b.teacherName;
    final partnerInitial =
        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?';

    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFECE5DD), // WhatsApp-like beige
        appBar: _buildAppBar(theme, partnerName, partnerInitial, b),
        body: Column(
          children: [
            // Messages
            Expanded(
              child: BlocConsumer<BookingBloc, BookingState>(
                listener: _onBlocState,
                builder: (ctx, state) {
                  if (_initialLoading && _messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_messages.isEmpty) return _emptyState();
                  return _messageList();
                },
              ),
            ),

            // Input bar or closed banner
            if (isPending) _inputBar(theme) else _closedBanner(theme),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    String partnerName,
    String partnerInitial,
    BookingRequest b,
  ) {
    return AppBar(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18.r,
            backgroundColor: Colors.white24,
            child: Text(
              partnerInitial,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          // Name + subject line
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${b.subjectName} · ${b.formattedDate}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Booking status badge in app bar
        Container(
          margin: EdgeInsets.only(right: 12.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: _statusColor(b.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            _statusLabel(b.status),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.green;
      case BookingStatus.declined:
        return Colors.red;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return 'En attente';
      case BookingStatus.accepted:
        return 'Acceptée';
      case BookingStatus.declined:
        return 'Refusée';
      case BookingStatus.cancelled:
        return 'Annulée';
    }
  }

  // ─── BLoC listener ────────────────────────────────────────────

  void _onBlocState(BuildContext ctx, BookingState state) {
    if (state is MessagesLoaded) {
      final oldCount = _messages.length;
      setState(() {
        _messages.clear();
        _messages.addAll(state.messages);
        _initialLoading = false;
      });
      if (state.messages.length > oldCount) {
        _scrollToBottom();
      } else if (oldCount == 0 && state.messages.isNotEmpty) {
        _scrollToBottom(animated: false);
      }
    } else if (state is MessageSent) {
      setState(() => _messages.add(state.message));
      _scrollToBottom();
    } else if (state is BookingError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Empty state ──────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_outlined,
                  size: 40.sp, color: AppTheme.primary),
            ),
            SizedBox(height: 20.h),
            Text(
              'Démarrer la conversation',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Discutez des détails, du prix, et des horaires\navant d\'accepter ou refuser la demande.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Message list with date separators ────────────────────────

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final showDate =
            i == 0 || !_isSameDay(msg.createdAt, _messages[i - 1].createdAt);

        // Check if next message is from same sender within 2 min → group
        final isLastInGroup = i == _messages.length - 1 ||
            _messages[i + 1].senderId != msg.senderId ||
            _messages[i + 1].createdAt.difference(msg.createdAt).inMinutes > 2;

        return Column(
          children: [
            if (showDate) _dateSeparator(msg.createdAt),
            _bubbleRow(msg, isLastInGroup),
          ],
        );
      },
    );
  }

  Widget _dateSeparator(DateTime dt) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            _dayLabel(dt),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667781),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Chat bubbles ─────────────────────────────────────────────

  Widget _bubbleRow(BookingMessage msg, bool isLastInGroup) {
    final isMe = msg.senderId == _currentUserId;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 6.h : 2.h,
        left: isMe ? 52.w : 0,
        right: isMe ? 0 : 52.w,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Small avatar for last in group (other person only)
          if (!isMe && isLastInGroup) ...[
            CircleAvatar(
              radius: 13.r,
              backgroundColor:
                  msg.isTeacher ? Colors.indigo.shade100 : Colors.teal.shade100,
              child: Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: msg.isTeacher
                      ? Colors.indigo.shade700
                      : Colors.teal.shade700,
                ),
              ),
            ),
            SizedBox(width: 4.w),
          ] else if (!isMe) ...[
            SizedBox(width: 30.w), // space for avatar alignment
          ],

          // Bubble
          Flexible(child: _bubble(msg, isMe, isLastInGroup)),
        ],
      ),
    );
  }

  Widget _bubble(BookingMessage msg, bool isMe, bool isLastInGroup) {
    final bubbleColor = isMe ? const Color(0xFFD9FDD3) : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 4.h),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe || !isLastInGroup ? 12.r : 4.r),
          topRight: Radius.circular(!isMe || !isLastInGroup ? 12.r : 4.r),
          bottomLeft: Radius.circular(12.r),
          bottomRight: Radius.circular(12.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name for first message in group (other side)
          if (!isMe && isLastInGroup)
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Text(
                msg.senderName,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: msg.isTeacher
                      ? Colors.indigo.shade600
                      : Colors.teal.shade600,
                ),
              ),
            ),

          // Content + time in a wrap
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF111B21),
                    height: 1.3,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Timestamp
              Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Text(
                  _timeLabel(msg.createdAt),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: const Color(0xFF667781),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Input bar ────────────────────────────────────────────────

  Widget _inputBar(ThemeData theme) {
    return Container(
      color: const Color(0xFFF0F0F0),
      padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        maxLines: 5,
                        minLines: 1,
                        style: TextStyle(fontSize: 14.sp),
                        decoration: InputDecoration(
                          hintText: 'Écrire un message...',
                          hintStyle: TextStyle(
                            color: const Color(0xFF999999),
                            fontSize: 14.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 10.h,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                ),
              ),
            ),
            SizedBox(width: 6.w),
            // Send button
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Closed booking banner ────────────────────────────────────

  Widget _closedBanner(ThemeData theme) {
    final status = widget.booking.status;
    final color = _statusColor(status);
    final label = status == BookingStatus.accepted
        ? 'Cette demande a été acceptée. La séance est créée ✓'
        : status == BookingStatus.declined
            ? 'Cette demande a été refusée.'
            : 'Cette demande a été annulée.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(top: BorderSide(color: color.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              status == BookingStatus.accepted
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 18.sp,
              color: color,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12.sp, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
