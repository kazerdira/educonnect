import 'package:get_it/get_it.dart';
import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/storage/secure_storage.dart';
import 'package:educonnect/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:educonnect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:educonnect/features/auth/domain/repositories/auth_repository.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';

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
    () => AuthRepositoryImpl(remoteDataSource: getIt(), secureStorage: getIt()),
  );
  getIt.registerFactory<AuthBloc>(() => AuthBloc(authRepository: getIt()));
}
