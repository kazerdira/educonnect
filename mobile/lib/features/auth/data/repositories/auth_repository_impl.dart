import 'dart:convert';

import 'package:educonnect/core/storage/secure_storage.dart';
import 'package:educonnect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:educonnect/features/auth/data/models/user_model.dart';
import 'package:educonnect/features/auth/domain/entities/user.dart';
import 'package:educonnect/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SecureStorage secureStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
  });

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await remoteDataSource.login(email: email, password: password);
    return _handleAuthResponse(data);
  }

  @override
  Future<AuthResult> registerTeacher({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
    String? bio,
    int? experienceYears,
  }) async {
    final data = await remoteDataSource.registerTeacher(
      email: email,
      phone: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
      wilaya: wilaya,
      bio: bio,
      experienceYears: experienceYears,
    );
    return _handleAuthResponse(data);
  }

  @override
  Future<AuthResult> registerParent({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
  }) async {
    final data = await remoteDataSource.registerParent(
      email: email,
      phone: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
      wilaya: wilaya,
    );
    return _handleAuthResponse(data);
  }

  @override
  Future<AuthResult> registerStudent({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
    required String levelCode,
    String? school,
    String? dateOfBirth,
  }) async {
    final data = await remoteDataSource.registerStudent(
      email: email,
      phone: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
      wilaya: wilaya,
      levelCode: levelCode,
      school: school,
      dateOfBirth: dateOfBirth,
    );
    return _handleAuthResponse(data);
  }

  @override
  Future<void> sendOtp({required String phone}) async {
    await remoteDataSource.sendOtp(phone: phone);
  }

  @override
  Future<AuthResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final data = await remoteDataSource.verifyOtp(phone: phone, code: code);
    return _handleAuthResponse(data);
  }

  @override
  Future<AuthResult> refreshToken() async {
    final storedRefreshToken = await secureStorage.getRefreshToken();
    if (storedRefreshToken == null) {
      throw Exception('No refresh token found');
    }
    final data = await remoteDataSource.refreshToken(
      refreshToken: storedRefreshToken,
    );
    return _handleAuthResponse(data);
  }

  @override
  Future<User?> getCurrentUser() async {
    final userData = await secureStorage.getUserData();
    if (userData == null) return null;
    return UserModel.fromJson(jsonDecode(userData) as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    await secureStorage.clearAll();
  }

  // ── Private helpers ─────────────────────────────────────────

  Future<AuthResult> _handleAuthResponse(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await secureStorage.saveUserData(jsonEncode((user as UserModel).toJson()));

    return AuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }
}
