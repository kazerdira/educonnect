import 'package:dio/dio.dart';
import 'package:educonnect/core/storage/secure_storage.dart';
import 'package:educonnect/core/network/api_constants.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorage secureStorage;

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
      _AuthInterceptor(secureStorage: secureStorage, dio: dio),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => print('  [API] $o'),
      ),
    ]);
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorage secureStorage;
  final Dio dio;

  _AuthInterceptor({required this.secureStorage, required this.dio});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.getAccessToken();
    if (token != null) {
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
        handler.next(err);
        return;
      }

      try {
        final response = await Dio().post(
          '${ApiConstants.baseUrl}/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        final data = response.data['data'];
        await secureStorage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );

        // Retry the original request
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer ${data['access_token']}';
        final retryResponse = await dio.fetch(options);
        handler.resolve(retryResponse);
      } catch (_) {
        await secureStorage.clearTokens();
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
