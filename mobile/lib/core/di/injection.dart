import 'package:get_it/get_it.dart';
import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/storage/secure_storage.dart';
import 'package:educonnect/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:educonnect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:educonnect/features/auth/domain/repositories/auth_repository.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/teacher/data/datasources/teacher_remote_datasource.dart';
import 'package:educonnect/features/teacher/data/repositories/teacher_repository_impl.dart';
import 'package:educonnect/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:educonnect/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:educonnect/features/search/data/datasources/search_remote_datasource.dart';
import 'package:educonnect/features/search/data/repositories/search_repository_impl.dart';
import 'package:educonnect/features/search/domain/repositories/search_repository.dart';
import 'package:educonnect/features/search/presentation/bloc/search_bloc.dart';
import 'package:educonnect/features/session/data/datasources/session_remote_datasource.dart';
import 'package:educonnect/features/session/data/repositories/session_repository_impl.dart';
import 'package:educonnect/features/session/domain/repositories/session_repository.dart';
import 'package:educonnect/features/session/presentation/bloc/session_bloc.dart';
import 'package:educonnect/features/parent/data/datasources/parent_remote_datasource.dart';
import 'package:educonnect/features/parent/data/repositories/parent_repository_impl.dart';
import 'package:educonnect/features/parent/domain/repositories/parent_repository.dart';
import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:educonnect/features/course/data/datasources/course_remote_datasource.dart';
import 'package:educonnect/features/course/data/repositories/course_repository_impl.dart';
import 'package:educonnect/features/course/domain/repositories/course_repository.dart';
import 'package:educonnect/features/course/presentation/bloc/course_bloc.dart';
import 'package:educonnect/features/review/data/datasources/review_remote_datasource.dart';
import 'package:educonnect/features/review/data/repositories/review_repository_impl.dart';
import 'package:educonnect/features/review/domain/repositories/review_repository.dart';
import 'package:educonnect/features/review/presentation/bloc/review_bloc.dart';
import 'package:educonnect/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:educonnect/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:educonnect/features/notification/domain/repositories/notification_repository.dart';
import 'package:educonnect/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:educonnect/features/payment/data/datasources/payment_remote_datasource.dart';
import 'package:educonnect/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:educonnect/features/payment/domain/repositories/payment_repository.dart';
import 'package:educonnect/features/payment/presentation/bloc/payment_bloc.dart';
import 'package:educonnect/features/homework/data/datasources/homework_remote_datasource.dart';
import 'package:educonnect/features/homework/data/repositories/homework_repository_impl.dart';
import 'package:educonnect/features/homework/domain/repositories/homework_repository.dart';
import 'package:educonnect/features/homework/presentation/bloc/homework_bloc.dart';
import 'package:educonnect/features/quiz/data/datasources/quiz_remote_datasource.dart';
import 'package:educonnect/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:educonnect/features/quiz/domain/repositories/quiz_repository.dart';
import 'package:educonnect/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:educonnect/features/student/data/datasources/student_remote_datasource.dart';
import 'package:educonnect/features/student/data/repositories/student_repository_impl.dart';
import 'package:educonnect/features/student/domain/repositories/student_repository.dart';
import 'package:educonnect/features/student/presentation/bloc/student_bloc.dart';
import 'package:educonnect/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:educonnect/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:educonnect/features/admin/domain/repositories/admin_repository.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // ── Core ────────────────────────────────────────────────────
  getIt.registerLazySingleton<SecureStorage>(() => SecureStorage());
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(secureStorage: getIt()),
  );

  // ── Auth ────────────────────────────────────────────────────
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      secureStorage: getIt(),
      apiClient: getIt(),
    ),
  );
  getIt.registerLazySingleton<AuthBloc>(
    () => AuthBloc(authRepository: getIt()),
  );

  // ── Session-expiry wiring ───────────────────────────────────
  // When a token refresh fails the interceptor fires this callback,
  // which dispatches a logout so the router redirects to login.
  getIt<ApiClient>().onSessionExpired = () {
    getIt<AuthBloc>().add(AuthLogoutRequested());
  };

  // ── Teacher ─────────────────────────────────────────────────
  getIt.registerLazySingleton<TeacherRemoteDataSource>(
    () => TeacherRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<TeacherRepository>(
    () => TeacherRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<TeacherBloc>(
    () => TeacherBloc(teacherRepository: getIt()),
  );

  // ── Search ──────────────────────────────────────────────────
  getIt.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<SearchBloc>(
    () => SearchBloc(searchRepository: getIt()),
  );

  // ── Session ─────────────────────────────────────────────────
  getIt.registerLazySingleton<SessionRemoteDataSource>(
    () => SessionRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<SessionRepository>(
    () => SessionRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<SessionBloc>(
    () => SessionBloc(sessionRepository: getIt()),
  );

  // ── Parent ──────────────────────────────────────────────────
  getIt.registerLazySingleton<ParentRemoteDataSource>(
    () => ParentRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<ParentRepository>(
    () => ParentRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<ParentBloc>(
    () => ParentBloc(parentRepository: getIt()),
  );

  // ── Course ──────────────────────────────────────────────────
  getIt.registerLazySingleton<CourseRemoteDataSource>(
    () => CourseRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<CourseRepository>(
    () => CourseRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<CourseBloc>(
    () => CourseBloc(courseRepository: getIt()),
  );

  // ── Review ──────────────────────────────────────────────────
  getIt.registerLazySingleton<ReviewRemoteDataSource>(
    () => ReviewRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<ReviewBloc>(
    () => ReviewBloc(reviewRepository: getIt()),
  );

  // ── Notification ────────────────────────────────────────────
  getIt.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<NotificationBloc>(
    () => NotificationBloc(notificationRepository: getIt()),
  );

  // ── Payment ─────────────────────────────────────────────────
  getIt.registerLazySingleton<PaymentRemoteDataSource>(
    () => PaymentRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<PaymentBloc>(
    () => PaymentBloc(paymentRepository: getIt()),
  );

  // ── Homework ────────────────────────────────────────────────
  getIt.registerLazySingleton<HomeworkRemoteDataSource>(
    () => HomeworkRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<HomeworkRepository>(
    () => HomeworkRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<HomeworkBloc>(
    () => HomeworkBloc(homeworkRepository: getIt()),
  );

  // ── Quiz ────────────────────────────────────────────────────
  getIt.registerLazySingleton<QuizRemoteDataSource>(
    () => QuizRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<QuizRepository>(
    () => QuizRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<QuizBloc>(
    () => QuizBloc(quizRepository: getIt()),
  );

  // ── Student ─────────────────────────────────────────────────
  getIt.registerLazySingleton<StudentRemoteDataSource>(
    () => StudentRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<StudentRepository>(
    () => StudentRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<StudentBloc>(
    () => StudentBloc(studentRepository: getIt()),
  );

  // ── Admin ───────────────────────────────────────────────────
  getIt.registerLazySingleton<AdminRemoteDataSource>(
    () => AdminRemoteDataSource(apiClient: getIt()),
  );
  getIt.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory<AdminBloc>(
    () => AdminBloc(adminRepository: getIt()),
  );
}
