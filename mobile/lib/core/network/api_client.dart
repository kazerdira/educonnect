import 'package:dio/dio.dart';
import 'package:educonnect/core/storage/secure_storage.dart';
import 'package:educonnect/core/network/api_constants.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorage secureStorage;

  /// In-memory token cache to avoid async storage read races.
  String? _cachedAccessToken;

  /// Called when a token refresh fails — the app should force re-login.
  void Function()? onSessionExpired;

  ApiClient({required this.secureStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(apiClient: this, secureStorage: secureStorage, dio: dio),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => print('  [API] $o'),
      ),
    ]);
  }

  /// Call after login/register to immediately make the token available.
  void setAccessToken(String? token) {
    _cachedAccessToken = token;
  }

  // ── Convenience wrappers ──────────────────────────────────────
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.post<T>(path,
          data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.put<T>(path,
          data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.delete<T>(path,
          data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.patch<T>(path,
          data: data, queryParameters: queryParameters, options: options);
}

class _AuthInterceptor extends Interceptor {
  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final Dio dio;

  _AuthInterceptor({
    required this.apiClient,
    required this.secureStorage,
    required this.dio,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Use in-memory cache first, fall back to secure storage
    final token =
        apiClient._cachedAccessToken ?? await secureStorage.getAccessToken();
    if (token != null) {
      apiClient._cachedAccessToken = token; // warm cache
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh the token
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null) {
        print('  [AUTH] No refresh token available — session expired');
        apiClient.onSessionExpired?.call();
        handler.next(err);
        return;
      }

      try {
        print('  [AUTH] Access token expired, attempting refresh…');
        final response = await Dio().post(
          '${ApiConstants.baseUrl}/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        final data = response.data['data'];
        final newAccessToken = data['access_token'] as String;
        await secureStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: data['refresh_token'],
        );
        apiClient._cachedAccessToken = newAccessToken;
        print('  [AUTH] Token refreshed successfully ✓');

        // Retry the original request
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await dio.fetch(options);
        handler.resolve(retryResponse);
      } catch (e) {
        print('  [AUTH] Token refresh failed: $e — forcing re-login');
        apiClient._cachedAccessToken = null;
        await secureStorage.clearTokens();
        apiClient.onSessionExpired?.call();
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
