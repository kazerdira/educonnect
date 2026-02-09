import 'package:educonnect/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<AuthResult> login({required String email, required String password});
  Future<AuthResult> registerTeacher({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
    String? bio,
    int? experienceYears,
  });
  Future<AuthResult> registerParent({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
  });
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
  });
  Future<void> sendOtp({required String phone});
  Future<AuthResult> verifyOtp({required String phone, required String code});
  Future<AuthResult> refreshToken();
  Future<User?> getCurrentUser();
  Future<void> logout();
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final User user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}
