import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/auth/presentation/pages/login_page.dart';
import 'package:educonnect/features/auth/presentation/pages/register_page.dart';
import 'package:educonnect/features/auth/presentation/pages/role_selection_page.dart';
import 'package:educonnect/features/home/presentation/pages/shell_page.dart';
import 'package:educonnect/features/splash/presentation/pages/splash_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_dashboard_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_profile_edit_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_offerings_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/create_offering_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_availability_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_earnings_page.dart';
import 'package:educonnect/features/teacher/presentation/pages/teacher_public_profile_page.dart';
import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/search/presentation/bloc/search_bloc.dart';
import 'package:educonnect/features/search/presentation/pages/search_page.dart';
import 'package:educonnect/features/session/presentation/bloc/session_bloc.dart';
import 'package:educonnect/features/session/presentation/pages/session_list_page.dart';
import 'package:educonnect/features/session/presentation/pages/session_detail_page.dart';
import 'package:educonnect/features/session/presentation/pages/create_session_page.dart';
import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:educonnect/features/parent/presentation/pages/parent_dashboard_page.dart';
import 'package:educonnect/features/parent/presentation/pages/children_list_page.dart';
import 'package:educonnect/features/parent/presentation/pages/add_child_page.dart';
import 'package:educonnect/features/parent/presentation/pages/child_detail_page.dart';
import 'package:educonnect/features/parent/presentation/pages/edit_child_page.dart';
import 'package:educonnect/features/parent/presentation/pages/child_progress_page.dart';
import 'package:educonnect/features/parent/domain/entities/child.dart' as ent;
import 'package:educonnect/features/course/presentation/bloc/course_bloc.dart';
import 'package:educonnect/features/course/presentation/pages/course_list_page.dart';
import 'package:educonnect/features/course/presentation/pages/course_detail_page.dart';
import 'package:educonnect/features/course/presentation/pages/create_course_page.dart';
import 'package:educonnect/features/review/presentation/bloc/review_bloc.dart';
import 'package:educonnect/features/review/presentation/pages/teacher_reviews_page.dart';
import 'package:educonnect/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:educonnect/features/notification/presentation/pages/notifications_page.dart';
import 'package:educonnect/features/notification/presentation/pages/notification_preferences_page.dart';
import 'package:educonnect/features/payment/presentation/bloc/payment_bloc.dart';
import 'package:educonnect/features/payment/presentation/pages/payment_history_page.dart';
import 'package:educonnect/features/payment/presentation/pages/initiate_payment_page.dart';
import 'package:educonnect/features/payment/presentation/pages/subscriptions_page.dart';
import 'package:educonnect/features/homework/presentation/bloc/homework_bloc.dart';
import 'package:educonnect/features/homework/presentation/pages/homework_list_page.dart';
import 'package:educonnect/features/homework/presentation/pages/homework_detail_page.dart';
import 'package:educonnect/features/homework/presentation/pages/create_homework_page.dart';
import 'package:educonnect/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:educonnect/features/quiz/presentation/pages/quiz_list_page.dart';
import 'package:educonnect/features/quiz/presentation/pages/quiz_detail_page.dart';
import 'package:educonnect/features/quiz/presentation/pages/create_quiz_page.dart';
import 'package:educonnect/features/student/presentation/bloc/student_bloc.dart';
import 'package:educonnect/features/student/presentation/pages/student_dashboard_page.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_users_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_verifications_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_disputes_page.dart';
import 'package:educonnect/features/admin/presentation/pages/admin_subjects_page.dart';
import 'package:educonnect/core/di/injection.dart';

/// Converts a [Stream] into a [ChangeNotifier] so GoRouter re-evaluates
/// its redirect whenever the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AuthBloc authBloc) => GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final isSplash = state.matchedLocation == '/splash';

        if (isSplash) return null;

        if (authState is AuthUnauthenticated && !isAuthRoute) {
          return '/auth/login';
        }

        if (authState is AuthAuthenticated && isAuthRoute) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
        GoRoute(path: '/auth/login', builder: (_, __) => const LoginPage()),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RoleSelectionPage(),
        ),
        GoRoute(
          path: '/auth/register/:role',
          builder: (_, state) =>
              RegisterPage(role: state.pathParameters['role'] ?? 'student'),
        ),
        GoRoute(path: '/home', builder: (_, __) => const ShellPage()),

        // ── Teacher routes ──────────────────────────────────────
        GoRoute(
          path: '/teacher/dashboard',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: const TeacherDashboardPage(),
          ),
        ),
        GoRoute(
          path: '/teacher/profile/edit',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: const TeacherProfileEditPage(),
          ),
        ),
        GoRoute(
          path: '/teacher/offerings',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: const TeacherOfferingsPage(),
          ),
        ),
        GoRoute(
          path: '/teacher/offerings/create',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: const CreateOfferingPage(),
          ),
        ),
        GoRoute(
          path: '/teacher/availability',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: const TeacherAvailabilityPage(),
          ),
        ),
        GoRoute(
          path: '/teacher/earnings',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: const TeacherEarningsPage(),
          ),
        ),
        // Public teacher profile — MUST be after all /teacher/xxx routes
        GoRoute(
          path: '/teacher/:id',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<TeacherBloc>(),
            child: TeacherPublicProfilePage(
              teacherId: state.pathParameters['id']!,
            ),
          ),
        ),

        // ── Search routes ───────────────────────────────────────
        GoRoute(
          path: '/search',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<SearchBloc>(),
            child: const SearchPage(),
          ),
        ),

        // ── Session routes ──────────────────────────────────────
        GoRoute(
          path: '/sessions',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<SessionBloc>(),
            child: const SessionListPage(),
          ),
        ),
        GoRoute(
          path: '/sessions/create',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<SessionBloc>(),
            child: const CreateSessionPage(),
          ),
        ),
        GoRoute(
          path: '/sessions/:id',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<SessionBloc>(),
            child: SessionDetailPage(
              sessionId: state.pathParameters['id']!,
            ),
          ),
        ),

        // ── Parent routes ───────────────────────────────────────
        GoRoute(
          path: '/parent/dashboard',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<ParentBloc>(),
            child: const ParentDashboardPage(),
          ),
        ),
        GoRoute(
          path: '/parent/children',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<ParentBloc>(),
            child: const ChildrenListPage(),
          ),
        ),
        GoRoute(
          path: '/parent/children/add',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<ParentBloc>(),
            child: const AddChildPage(),
          ),
        ),
        GoRoute(
          path: '/parent/children/:id',
          builder: (_, state) {
            final child = state.extra as ent.Child;
            return ChildDetailPage(child: child);
          },
        ),
        GoRoute(
          path: '/parent/children/:id/edit',
          builder: (_, state) {
            final child = state.extra as ent.Child;
            return BlocProvider(
              create: (_) => getIt<ParentBloc>(),
              child: EditChildPage(child: child),
            );
          },
        ),
        GoRoute(
          path: '/parent/children/:id/progress',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<ParentBloc>(),
            child: ChildProgressPage(
              childId: state.pathParameters['id']!,
            ),
          ),
        ),

        // ── Course routes ───────────────────────────────────────
        GoRoute(
          path: '/courses',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<CourseBloc>(),
            child: const CourseListPage(),
          ),
        ),
        GoRoute(
          path: '/courses/create',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<CourseBloc>(),
            child: const CreateCoursePage(),
          ),
        ),
        GoRoute(
          path: '/courses/:id',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<CourseBloc>(),
            child: CourseDetailPage(
              courseId: state.pathParameters['id']!,
            ),
          ),
        ),

        // ── Review routes ───────────────────────────────────────
        GoRoute(
          path: '/reviews/teacher/:teacherId',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<ReviewBloc>(),
            child: TeacherReviewsPage(
              teacherId: state.pathParameters['teacherId']!,
              teacherName: state.uri.queryParameters['name'] ?? '',
            ),
          ),
        ),

        // ── Notification routes ─────────────────────────────────
        GoRoute(
          path: '/notifications',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<NotificationBloc>(),
            child: const NotificationsPage(),
          ),
        ),
        GoRoute(
          path: '/notifications/preferences',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<NotificationBloc>(),
            child: const NotificationPreferencesPage(),
          ),
        ),

        // ── Payment routes ──────────────────────────────────────
        GoRoute(
          path: '/payments/history',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<PaymentBloc>(),
            child: const PaymentHistoryPage(),
          ),
        ),
        GoRoute(
          path: '/payments/initiate',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<PaymentBloc>(),
            child: const InitiatePaymentPage(),
          ),
        ),
        GoRoute(
          path: '/subscriptions',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<PaymentBloc>(),
            child: const SubscriptionsPage(),
          ),
        ),

        // ── Homework routes ─────────────────────────────────────
        GoRoute(
          path: '/homework',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<HomeworkBloc>(),
            child: const HomeworkListPage(),
          ),
        ),
        GoRoute(
          path: '/homework/create',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<HomeworkBloc>(),
            child: const CreateHomeworkPage(),
          ),
        ),
        GoRoute(
          path: '/homework/:id',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<HomeworkBloc>(),
            child: HomeworkDetailPage(
              homeworkId: state.pathParameters['id']!,
            ),
          ),
        ),

        // ── Quiz routes ─────────────────────────────────────────
        GoRoute(
          path: '/quizzes',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<QuizBloc>(),
            child: const QuizListPage(),
          ),
        ),
        GoRoute(
          path: '/quizzes/create',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<QuizBloc>(),
            child: const CreateQuizPage(),
          ),
        ),
        GoRoute(
          path: '/quizzes/:id',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<QuizBloc>(),
            child: QuizDetailPage(
              quizId: state.pathParameters['id']!,
            ),
          ),
        ),

        // ── Student routes ──────────────────────────────────────
        GoRoute(
          path: '/student/dashboard',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<StudentBloc>(),
            child: const StudentDashboardPage(),
          ),
        ),

        // ── Admin routes ────────────────────────────────────────
        GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<AdminBloc>(),
            child: const AdminDashboardPage(),
          ),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<AdminBloc>(),
            child: const AdminUsersPage(),
          ),
        ),
        GoRoute(
          path: '/admin/verifications',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<AdminBloc>(),
            child: const AdminVerificationsPage(),
          ),
        ),
        GoRoute(
          path: '/admin/disputes',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<AdminBloc>(),
            child: const AdminDisputesPage(),
          ),
        ),
        GoRoute(
          path: '/admin/subjects',
          builder: (_, __) => BlocProvider(
            create: (_) => getIt<AdminBloc>(),
            child: const AdminSubjectsPage(),
          ),
        ),
      ],
    );
