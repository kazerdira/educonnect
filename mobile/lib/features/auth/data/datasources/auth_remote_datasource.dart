import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';

class AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSource({required this.apiClient});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Login failed: no data in response');
    return data;
  }

  Future<Map<String, dynamic>> registerTeacher({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
    String? bio,
    int? experienceYears,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.registerTeacher,
      data: {
        'email': email,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'wilaya': wilaya,
        if (bio != null) 'bio': bio,
        if (experienceYears != null) 'experience_years': experienceYears,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('Registration failed: no data in response');
    return data;
  }

  Future<Map<String, dynamic>> registerParent({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String wilaya,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.registerParent,
      data: {
        'email': email,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'wilaya': wilaya,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('Registration failed: no data in response');
    return data;
  }

  Future<Map<String, dynamic>> registerStudent({
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
    final response = await apiClient.dio.post(
      ApiConstants.registerStudent,
      data: {
        'email': email,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'wilaya': wilaya,
        'level_code': levelCode,
        if (school != null) 'school': school,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('Registration failed: no data in response');
    return data;
  }

  Future<void> sendOtp({required String phone}) async {
    await apiClient.dio.post(ApiConstants.phoneLogin, data: {'phone': phone});
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.verifyOtp,
      data: {'phone': phone, 'code': code},
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('OTP verification failed: no data');
    return data;
  }

  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await apiClient.dio.post(
      ApiConstants.refreshToken,
      data: {'refresh_token': refreshToken},
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Token refresh failed: no data');
    return data;
  }
}
