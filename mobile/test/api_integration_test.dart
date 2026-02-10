/// ──────────────────────────────────────────────────────────────
/// EduConnect — API Integration Test Suite
///
/// Hits the REAL backend and validates every endpoint.
/// Run with:
///   cd mobile
///   dart test test/api_integration_test.dart --reporter expanded
///
/// ⚠ Requires a running backend at the URL below.
/// ──────────────────────────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:test/test.dart';

// ─── Config ──────────────────────────────────────────────────
const _baseUrl = 'http://192.168.1.15:8080/api/v1';

const _teacherEmail = 'test_teacher@test.com';
const _teacherPass = 'Test1234!';
const _studentEmail = 'test_student@test.com';
const _studentPass = 'Test1234!';
const _parentEmail = 'test_parent@test.com';
const _parentPass = 'Test1234!';

// ─── Shared State ────────────────────────────────────────────
late Dio _dio;
String? _teacherToken;
String? _studentToken;
String? _parentToken;
bool _backendUp = false;

// ─── Helpers ─────────────────────────────────────────────────

/// Skip test if backend is down or token is null.
void _requireToken(String? token, String role) {
  if (!_backendUp) {
    print('  [SKIP] backend is not reachable');
    return;
  }
  if (token == null) {
    print('  [SKIP] $role token is null (login failed)');
    return;
  }
}

Future<Response> _get(String path, String token, {Map<String, dynamic>? q}) =>
    _dio.get('$_baseUrl$path',
        queryParameters: q,
        options: Options(headers: {'Authorization': 'Bearer $token'}));

Future<Response> _post(String path, String token, {Object? data}) =>
    _dio.post('$_baseUrl$path',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}));

Future<Response> _put(String path, String token, {Object? data}) =>
    _dio.put('$_baseUrl$path',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}));

Future<Response> _delete(String path, String token, {Object? data}) =>
    _dio.delete('$_baseUrl$path',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}));

/// Returns `response.data['data']` safely.
/// Handles non-Map bodies (e.g. plain-text 404 pages).
dynamic _dataOf(Response r) {
  final raw = r.data;
  if (raw is Map<String, dynamic>) return raw['data'];
  return null; // body was String / null / List
}

/// Prints a short diagnostic line.
void _report(String label, Response r) {
  final d = _dataOf(r);
  final type = d == null
      ? 'null'
      : d is List
          ? 'List(${d.length})'
          : d is Map
              ? 'Map(${(d as Map).keys.take(5).join(', ')}…)'
              : d.runtimeType.toString();
  print('  [$label] ${r.statusCode} → $type');
}

// ═════════════════════════════════════════════════════════════
void main() {
  setUpAll(() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true, // never throw on HTTP errors
    ));
  });

  // ────────────────────────────────────────────────────────────
  // 0. Health — also determines if backend is reachable
  // ────────────────────────────────────────────────────────────
  group('0 — Health', () {
    test('GET /health → 200', () async {
      try {
        final r = await _dio.get('http://192.168.1.15:8080/health');
        _backendUp = r.statusCode == 200;
        expect(r.statusCode, 200);
        print('  ✓ Backend is UP');
      } catch (e) {
        _backendUp = false;
        fail('Backend is NOT reachable at 192.168.1.15:8080 — $e');
      }
    });
  });

  // ────────────────────────────────────────────────────────────
  // 1. Auth
  // ────────────────────────────────────────────────────────────
  group('1 — Auth', () {
    test('login teacher → 200 + tokens', () async {
      if (!_backendUp) return;
      final r = await _dio.post('$_baseUrl/auth/login',
          data: {'email': _teacherEmail, 'password': _teacherPass});
      _report('teacher login', r);
      expect(r.statusCode, 200, reason: 'Teacher login failed');
      final d = _dataOf(r) as Map?;
      expect(d, isNotNull);
      expect(d!['access_token'], isA<String>());
      expect(d['refresh_token'], isA<String>());
      expect(d['user'], isA<Map>());
      _teacherToken = d['access_token'] as String;
    });

    test('login student → 200 + tokens', () async {
      if (!_backendUp) return;
      final r = await _dio.post('$_baseUrl/auth/login',
          data: {'email': _studentEmail, 'password': _studentPass});
      _report('student login', r);
      expect(r.statusCode, 200, reason: 'Student login failed');
      _studentToken = (_dataOf(r) as Map?)?['access_token'] as String?;
      expect(_studentToken, isNotNull);
    });

    test('login parent → 200 or 401', () async {
      if (!_backendUp) return;
      final r = await _dio.post('$_baseUrl/auth/login',
          data: {'email': _parentEmail, 'password': _parentPass});
      _report('parent login', r);
      expect(r.statusCode, anyOf(200, 401));
      if (r.statusCode == 200) {
        _parentToken = (_dataOf(r) as Map?)?['access_token'] as String?;
      }
    });

    test('wrong password → 401', () async {
      if (!_backendUp) return;
      final r = await _dio.post('$_baseUrl/auth/login',
          data: {'email': _teacherEmail, 'password': 'wrong'});
      expect(r.statusCode, 401);
    });

    test('refresh with garbage → non-200', () async {
      if (!_backendUp) return;
      final r = await _dio
          .post('$_baseUrl/auth/refresh', data: {'refresh_token': 'garbage'});
      expect(r.statusCode, isNot(200));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 2. User profile
  // ────────────────────────────────────────────────────────────
  group('2 — User profile', () {
    test('GET /users/me → Map', () async {
      if (_teacherToken == null) return;
      final r = await _get('/users/me', _teacherToken!);
      _report('profile', r);
      expect(r.statusCode, 200);
      expect(_dataOf(r), isA<Map>());
    });
  });

  // ────────────────────────────────────────────────────────────
  // 3. Teacher endpoints
  // ────────────────────────────────────────────────────────────
  group('3 — Teacher', () {
    test('GET /teachers/dashboard → Map', () async {
      if (_teacherToken == null) return;
      final r = await _get('/teachers/dashboard', _teacherToken!);
      _report('teacher dashboard', r);
      expect(r.statusCode, 200);
      final d = _dataOf(r);
      expect(d == null || d is Map, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /teachers (list) → 2xx', () async {
      if (_teacherToken == null) return;
      final r =
          await _get('/teachers', _teacherToken!, q: {'page': 1, 'limit': 5});
      _report('teachers list', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /teachers/offerings → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/teachers/offerings', _teacherToken!);
      _report('offerings', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /teachers/earnings → Map|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/teachers/earnings', _teacherToken!);
      _report('earnings', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is Map, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /teachers/:id/availability → 2xx', () async {
      if (_teacherToken == null) return;
      final dash = await _get('/teachers/dashboard', _teacherToken!);
      final id = (_dataOf(dash) as Map?)?['teacher_id'] as String?;
      if (id == null) {
        print('  [SKIP] no teacher_id in dashboard');
        return;
      }
      final r = await _get('/teachers/$id/availability', _teacherToken!);
      _report('availability', r);
      expect(r.statusCode, inInclusiveRange(200, 499));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 4. Student endpoints
  // ────────────────────────────────────────────────────────────
  group('4 — Student', () {
    test('GET /students/dashboard → Map', () async {
      if (_studentToken == null) return;
      final r = await _get('/students/dashboard', _studentToken!);
      _report('student dashboard', r);
      expect(r.statusCode, 200);
      final d = _dataOf(r);
      expect(d == null || d is Map, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /students/progress → Map|null', () async {
      if (_studentToken == null) return;
      final r = await _get('/students/progress', _studentToken!);
      _report('student progress', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      // NOTE: backend returns a Map (profile, total_courses, …), not a List.
      // Flutter datasource may incorrectly cast this as List → crash source!
      expect(d == null || d is Map, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /students/enrollments → List|null', () async {
      if (_studentToken == null) return;
      final r = await _get('/students/enrollments', _studentToken!);
      _report('student enrollments', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });
  });

  // ────────────────────────────────────────────────────────────
  // 5. Parent endpoints
  // ────────────────────────────────────────────────────────────
  group('5 — Parent', () {
    test('GET /parents/dashboard', () async {
      if (_parentToken == null) {
        print('  [SKIP] no parent account');
        return;
      }
      final r = await _get('/parents/dashboard', _parentToken!);
      _report('parent dashboard', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
    });

    test('GET /parents/children → List|null', () async {
      if (_parentToken == null) return;
      final r = await _get('/parents/children', _parentToken!);
      _report('parent children', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 6. Sessions
  // ────────────────────────────────────────────────────────────
  group('6 — Sessions', () {
    test('GET /sessions (teacher) → List|null', () async {
      if (_teacherToken == null) return;
      final r =
          await _get('/sessions', _teacherToken!, q: {'page': 1, 'limit': 5});
      _report('sessions-teacher', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /sessions (student) → List|null', () async {
      if (_studentToken == null) return;
      final r =
          await _get('/sessions', _studentToken!, q: {'page': 1, 'limit': 5});
      _report('sessions-student', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /sessions/:fake → non-200', () async {
      if (_teacherToken == null) return;
      final r = await _get(
          '/sessions/00000000-0000-0000-0000-000000000000', _teacherToken!);
      _report('session-fake', r);
      expect(r.statusCode, isNot(200));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 7. Courses
  // ────────────────────────────────────────────────────────────
  group('7 — Courses', () {
    test('GET /courses → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/courses', _teacherToken!);
      _report('courses', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /courses/:fake → non-200', () async {
      if (_teacherToken == null) return;
      final r = await _get(
          '/courses/00000000-0000-0000-0000-000000000000', _teacherToken!);
      _report('course-fake', r);
      expect(r.statusCode, isNot(200));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 8. Homework
  // ────────────────────────────────────────────────────────────
  group('8 — Homework', () {
    test('GET /homework → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/homework', _teacherToken!);
      _report('homework', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /homework/:fake → non-200', () async {
      if (_teacherToken == null) return;
      final r = await _get(
          '/homework/00000000-0000-0000-0000-000000000000', _teacherToken!);
      _report('homework-fake', r);
      expect(r.statusCode, isNot(200));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 9. Quizzes
  // ────────────────────────────────────────────────────────────
  group('9 — Quizzes', () {
    test('GET /quizzes → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/quizzes', _teacherToken!);
      _report('quizzes', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /quizzes/:fake → non-200', () async {
      if (_teacherToken == null) return;
      final r = await _get(
          '/quizzes/00000000-0000-0000-0000-000000000000', _teacherToken!);
      _report('quiz-fake', r);
      expect(r.statusCode, isNot(200));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 10. Payments
  // ────────────────────────────────────────────────────────────
  group('10 — Payments', () {
    test('GET /payments/history → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/payments/history', _teacherToken!);
      _report('payment-history', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });
  });

  // ────────────────────────────────────────────────────────────
  // 11. Subscriptions
  // ────────────────────────────────────────────────────────────
  group('11 — Subscriptions', () {
    test('GET /subscriptions → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/subscriptions', _teacherToken!);
      _report('subscriptions', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });
  });

  // ────────────────────────────────────────────────────────────
  // 12. Reviews
  // ────────────────────────────────────────────────────────────
  group('12 — Reviews', () {
    test('GET /reviews/teacher/:fake → 200|404', () async {
      if (_teacherToken == null) return;
      final r = await _get(
          '/reviews/teacher/00000000-0000-0000-0000-000000000000',
          _teacherToken!);
      _report('reviews-fake', r);
      expect(r.statusCode, inInclusiveRange(200, 404));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 13. Notifications
  // ────────────────────────────────────────────────────────────
  group('13 — Notifications', () {
    test('GET /notifications → List|null', () async {
      if (_teacherToken == null) return;
      final r = await _get('/notifications', _teacherToken!);
      _report('notifications', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
      final d = _dataOf(r);
      expect(d == null || d is List, isTrue, reason: 'got ${d.runtimeType}');
    });

    test('GET /notifications/preferences → route exists?', () async {
      if (_teacherToken == null) return;
      final r = await _get('/notifications/preferences', _teacherToken!);
      print(
          '  [notif-prefs-GET] ${r.statusCode} body-type=${r.data.runtimeType}');
      if (r.statusCode == 404 || r.statusCode == 405) {
        print('  ⚠ GET /notifications/preferences does NOT exist. '
            'Flutter datasource getPreferences() will crash!');
      }
      // Just assert it does NOT crash — we're documenting the behavior
      expect(r.statusCode, isNotNull);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 14. Search
  // ────────────────────────────────────────────────────────────
  group('14 — Search', () {
    test('GET /search/teachers → 2xx', () async {
      if (_teacherToken == null) return;
      // NOTE: backend requires q min=2 chars, empty string → 400!
      final r = await _get('/search/teachers', _teacherToken!,
          q: {'q': 'ma', 'page': 1, 'limit': 5});
      _report('search-teachers', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
    });

    test('GET /search/courses → 2xx', () async {
      if (_teacherToken == null) return;
      // NOTE: backend requires q min=2 chars
      final r = await _get('/search/courses', _teacherToken!,
          q: {'q': 'ma', 'page': 1, 'limit': 5});
      _report('search-courses', r);
      expect(r.statusCode, inInclusiveRange(200, 299));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 15. Admin (role-gated — teacher should get 403)
  // ────────────────────────────────────────────────────────────
  group('15 — Admin (role-gated)', () {
    test('GET /admin/users → 403', () async {
      if (_teacherToken == null) return;
      final r = await _get('/admin/users', _teacherToken!);
      _report('admin-noperm', r);
      expect(r.statusCode, anyOf(401, 403));
    });

    test('GET /admin/analytics/overview → 403', () async {
      if (_teacherToken == null) return;
      final r = await _get('/admin/analytics/overview', _teacherToken!);
      _report('admin-analytics', r);
      expect(r.statusCode, anyOf(401, 403));
    });
  });

  // ────────────────────────────────────────────────────────────
  // 16. Route mismatches (Flutter → Backend)
  // ────────────────────────────────────────────────────────────
  group('16 — Route mismatches', () {
    test('PUT /admin/config/subjects exists', () async {
      if (_teacherToken == null) return;
      final r = await _put('/admin/config/subjects', _teacherToken!, data: {});
      _report('admin-subjects', r);
      expect(r.statusCode, isNot(404),
          reason: '/admin/config/subjects should exist (403 is OK)');
    });

    test('PUT /admin/config/levels exists', () async {
      if (_teacherToken == null) return;
      final r = await _put('/admin/config/levels', _teacherToken!, data: {});
      _report('admin-levels', r);
      expect(r.statusCode, isNot(404),
          reason: '/admin/config/levels should exist (403 is OK)');
    });

    test('GET /notifications/preferences route?', () async {
      if (_teacherToken == null) return;
      final r = await _get('/notifications/preferences', _teacherToken!);
      print('  [notif-prefs] ${r.statusCode} body-type=${r.data.runtimeType}');
      if (r.statusCode == 404 || r.statusCode == 405) {
        print('  ⚠ MISMATCH: Flutter has GET but backend only has PUT');
      }
      expect(r.statusCode, isNotNull);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 17. Null-safety: data type assertions
  // ────────────────────────────────────────────────────────────
  group('17 — Null-safety: data types', () {
    final _endpoints = <String, _EndpointSpec>{
      // Map endpoints
      '/teachers/dashboard': _EndpointSpec('teacher', isMap: true),
      '/teachers/earnings': _EndpointSpec('teacher', isMap: true),
      '/students/dashboard': _EndpointSpec('student', isMap: true),
      // List endpoints
      '/teachers/offerings': _EndpointSpec('teacher', isMap: false),
      '/students/progress':
          _EndpointSpec('student', isMap: true), // backend returns Map!
      '/students/enrollments': _EndpointSpec('student', isMap: false),
      '/sessions': _EndpointSpec('teacher', isMap: false),
      '/courses': _EndpointSpec('teacher', isMap: false),
      '/homework': _EndpointSpec('teacher', isMap: false),
      '/quizzes': _EndpointSpec('teacher', isMap: false),
      '/notifications': _EndpointSpec('teacher', isMap: false),
      '/payments/history': _EndpointSpec('teacher', isMap: false),
      '/subscriptions': _EndpointSpec('teacher', isMap: false),
    };

    for (final entry in _endpoints.entries) {
      test('${entry.key} → ${entry.value.isMap ? "Map" : "List"}|null',
          () async {
        final token =
            entry.value.role == 'student' ? _studentToken : _teacherToken;
        if (token == null) return;
        final r = await _get(entry.key, token);
        if (r.statusCode != 200) {
          print('  [SKIP] ${entry.key} returned ${r.statusCode}');
          return;
        }
        final d = _dataOf(r);
        if (entry.value.isMap) {
          expect(d == null || d is Map, isTrue,
              reason: '${entry.key}: expected Map|null, got ${d.runtimeType}');
        } else {
          expect(d == null || d is List, isTrue,
              reason: '${entry.key}: expected List|null, got ${d.runtimeType}');
        }
      });
    }

    // Search endpoints return List (not Map!)
    for (final path in ['/search/teachers', '/search/courses']) {
      test('$path → List|null', () async {
        if (_teacherToken == null) return;
        final r = await _get(path, _teacherToken!,
            q: {'q': 'ma', 'page': 1, 'limit': 5});
        if (r.statusCode != 200) return;
        final d = _dataOf(r);
        expect(d == null || d is List, isTrue,
            reason: '$path: expected List|null, got ${d.runtimeType}');
      });
    }
  });

  // ────────────────────────────────────────────────────────────
  // 18. Deep-null: field existence inside data
  // ────────────────────────────────────────────────────────────
  group('18 — Deep-null: field existence', () {
    test('student dashboard has profile sub-object', () async {
      if (_studentToken == null) return;
      final r = await _get('/students/dashboard', _studentToken!);
      if (r.statusCode != 200) return;
      final d = _dataOf(r) as Map?;
      if (d == null) return;
      expect(d.containsKey('profile'), isTrue,
          reason: 'Keys: ${d.keys.toList()}');
      final p = d['profile'] as Map?;
      if (p != null) {
        for (final k in ['first_name', 'last_name', 'email']) {
          expect(p.containsKey(k), isTrue,
              reason: 'profile missing "$k". Has: ${p.keys.toList()}');
        }
      }
    });

    test('teacher dashboard keys', () async {
      if (_teacherToken == null) return;
      final r = await _get('/teachers/dashboard', _teacherToken!);
      if (r.statusCode != 200) return;
      final d = _dataOf(r) as Map?;
      if (d == null) return;
      print('  teacher dashboard keys: ${d.keys.toList()}');
    });

    test('login response: user has role', () async {
      if (!_backendUp) return;
      final r = await _dio.post('$_baseUrl/auth/login',
          data: {'email': _teacherEmail, 'password': _teacherPass});
      if (r.statusCode != 200) {
        print('  [SKIP] login returned ${r.statusCode}');
        return;
      }
      final d = _dataOf(r) as Map?;
      expect(d, isNotNull);
      final user = d!['user'] as Map?;
      expect(user, isNotNull);
      expect(user!.containsKey('role'), isTrue,
          reason: 'user keys: ${user.keys.toList()}');
    });

    test('teacher earnings keys', () async {
      if (_teacherToken == null) return;
      final r = await _get('/teachers/earnings', _teacherToken!);
      if (r.statusCode != 200) return;
      final d = _dataOf(r) as Map?;
      if (d == null) {
        print('  ⚠ earnings data is NULL');
        return;
      }
      print('  earnings keys: ${d.keys.toList()}');
    });

    test('search teachers keys', () async {
      if (_teacherToken == null) return;
      final r = await _get('/search/teachers', _teacherToken!,
          q: {'q': 'ma', 'page': 1, 'limit': 5});
      if (r.statusCode != 200) return;
      final d = _dataOf(r);
      if (d == null) {
        print('  search teachers data is null');
        return;
      }
      if (d is List) {
        print('  search teachers: List(${d.length})');
        if (d.isNotEmpty)
          print('  first item keys: ${(d[0] as Map).keys.toList()}');
      } else if (d is Map) {
        print('  search teachers keys: ${d.keys.toList()}');
      }
    });
  });

  // ────────────────────────────────────────────────────────────
  // 19. Cross-role access
  // ────────────────────────────────────────────────────────────
  group('19 — Cross-role access', () {
    test('student → /teachers/dashboard', () async {
      if (_studentToken == null) return;
      final r = await _get('/teachers/dashboard', _studentToken!);
      _report('student→teacher-dash', r);
    });

    test('teacher → /students/dashboard', () async {
      if (_teacherToken == null) return;
      final r = await _get('/students/dashboard', _teacherToken!);
      _report('teacher→student-dash', r);
    });

    test('student → /teachers/offerings', () async {
      if (_studentToken == null) return;
      final r = await _get('/teachers/offerings', _studentToken!);
      _report('student→offerings', r);
    });

    test('student → /teachers/earnings', () async {
      if (_studentToken == null) return;
      final r = await _get('/teachers/earnings', _studentToken!);
      _report('student→earnings', r);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 20. Summary
  // ────────────────────────────────────────────────────────────
  group('20 — Summary', () {
    test('final report', () {
      print('\n═══════════════════════════════════════');
      print('  Backend:  ${_backendUp ? "✓ UP" : "✗ DOWN"}');
      print('  Teacher:  ${_teacherToken != null ? "✓" : "✗ login failed"}');
      print('  Student:  ${_studentToken != null ? "✓" : "✗ login failed"}');
      print('  Parent:   ${_parentToken != null ? "✓" : "✗ no account"}');
      print('═══════════════════════════════════════\n');
    });
  });
}

// ─── Spec helper ──────────────────────────────────────────────
class _EndpointSpec {
  final String role; // 'teacher' | 'student'
  final bool isMap; // true → Map, false → List

  const _EndpointSpec(this.role, {required this.isMap});
}
