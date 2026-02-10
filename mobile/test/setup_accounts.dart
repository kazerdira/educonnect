import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  const base = 'http://192.168.1.15:8080/api/v1';

  // 1) Check exact login error
  print('=== LOGIN ATTEMPT (teacher) ===');
  var r = await dio.post('$base/auth/login',
      data: {'email': 'test_teacher@test.com', 'password': 'Test1234!'});
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');

  // 2) Register teacher (role-specific endpoint, phone+wilaya required)
  print('\n=== REGISTER teacher ===');
  r = await dio.post('$base/auth/register/teacher', data: {
    'email': 'test_teacher@test.com',
    'password': 'Test1234!',
    'first_name': 'Test',
    'last_name': 'Teacher',
    'phone': '0550000001',
    'wilaya': 'Alger',
    'bio': 'Test teacher account',
    'experience_years': 5,
    'specializations': ['math'],
  });
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');

  // 3) Register student (use unique phone to avoid 409)
  print('\n=== REGISTER student ===');
  r = await dio.post('$base/auth/register/student', data: {
    'email': 'test_student@test.com',
    'password': 'Test1234!',
    'first_name': 'Eleve',
    'last_name': 'Test',
    'phone': '0551111002',
    'wilaya': 'Alger',
    'level_code': '3AM',
  });
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');

  // 4) Register parent
  print('\n=== REGISTER parent ===');
  r = await dio.post('$base/auth/register/parent', data: {
    'email': 'test_parent@test.com',
    'password': 'Test1234!',
    'first_name': 'Parent',
    'last_name': 'Test',
    'phone': '0551111003',
    'wilaya': 'Alger',
    'children': [
      {
        'first_name': 'Child',
        'last_name': 'Test',
        'date_of_birth': '2012-05-15',
        'level_code': '3AM',
      }
    ],
  });
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');

  // 5) Retry logins after registration
  print('\n=== RE-LOGIN teacher ===');
  r = await dio.post('$base/auth/login',
      data: {'email': 'test_teacher@test.com', 'password': 'Test1234!'});
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');

  print('\n=== RE-LOGIN student ===');
  r = await dio.post('$base/auth/login',
      data: {'email': 'test_student@test.com', 'password': 'Test1234!'});
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');

  print('\n=== RE-LOGIN parent ===');
  r = await dio.post('$base/auth/login',
      data: {'email': 'test_parent@test.com', 'password': 'Test1234!'});
  print('Status: ${r.statusCode}');
  print('Body: ${r.data}');
}
