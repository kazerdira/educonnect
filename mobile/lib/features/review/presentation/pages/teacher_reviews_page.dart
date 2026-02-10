import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/review/domain/entities/review.dart';
import 'package:educonnect/features/review/presentation/bloc/review_bloc.dart';

class TeacherReviewsPage extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherReviewsPage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherReviewsPage> createState() => _TeacherReviewsPageState();
}

class _TeacherReviewsPageState extends State<TeacherReviewsPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<ReviewBloc>()
        .add(TeacherReviewsRequested(teacherId: widget.teacherId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Avis – ${widget.teacherName}'),
      ),
      body: BlocConsumer<ReviewBloc, ReviewState>(
        listener: (context, state) {
          if (state is ReviewResponded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Réponse envoyée')),
            );
            context
                .read<ReviewBloc>()
                .add(TeacherReviewsRequested(teacherId: state.teacherId));
          }
          if (state is ReviewError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is ReviewLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TeacherReviewsLoaded) {
            return _buildContent(context, state.result);
          }

          if (state is ReviewError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                  SizedBox(height: 12.h),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => context.read<ReviewBloc>().add(
                          TeacherReviewsRequested(teacherId: widget.teacherId),
                        ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, TeacherReviewsResult result) {
    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<ReviewBloc>()
            .add(TeacherReviewsRequested(teacherId: widget.teacherId));
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildSummaryCard(context, result.summary),
          SizedBox(height: 16.h),
          Text(
            'Avis (${result.reviews.length})',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          if (result.reviews.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  'Aucun avis pour le moment',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
              ),
            )
          else
            ...result.reviews.map((r) => _buildReviewCard(context, r)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, TeacherReviewSummary summary) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  summary.averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < summary.averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20.sp,
                        );
                      }),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${summary.totalReviews} avis au total',
                      style:
                          TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildRatingBar(
                '5 étoiles', summary.rating5Count, summary.totalReviews, theme),
            SizedBox(height: 4.h),
            _buildRatingBar(
                '4 étoiles', summary.rating4Count, summary.totalReviews, theme),
            SizedBox(height: 4.h),
            _buildRatingBar(
                '3 étoiles', summary.rating3Count, summary.totalReviews, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, int count, int total, ThemeData theme) {
    final ratio = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 72.w,
          child: Text(label, style: TextStyle(fontSize: 12.sp)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8.h,
              backgroundColor: Colors.grey[300],
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 24.w,
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12.sp),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, Review review) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    review.reviewerName.isNotEmpty
                        ? review.reviewerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                      Text(
                        review.createdAt,
                        style:
                            TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16.sp,
                    );
                  }),
                ),
              ],
            ),

            // ── Comment ──
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(review.comment!, style: TextStyle(fontSize: 13.sp)),
            ],

            // ── Teacher response ──
            if (review.response != null && review.response!.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réponse de l\'enseignant',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      review.response!,
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            ],

            // ── Respond button (only if no response yet) ──
            if (review.response == null || review.response!.isEmpty) ...[
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showRespondDialog(context, review),
                  icon: Icon(Icons.reply, size: 16.sp),
                  label: const Text('Répondre'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRespondDialog(BuildContext context, Review review) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Répondre à l\'avis'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Votre réponse…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                context.read<ReviewBloc>().add(
                      RespondToReviewRequested(
                        reviewId: review.id,
                        responseText: text,
                        teacherId: widget.teacherId,
                      ),
                    );
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}
