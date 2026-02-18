import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/search/data/models/search_result_model.dart';

class SearchRemoteDataSource {
  final ApiClient apiClient;

  SearchRemoteDataSource({required this.apiClient});

  /// Parse search response: {data: [...hits], meta: {total, page, limit, processing_time_ms}}
  SearchResultModel _parseSearchResponse(dynamic responseData) {
    final hits = responseData['data'];
    final meta = responseData['meta'] as Map<String, dynamic>? ?? {};

    final hitsList = (hits is List) ? hits : <dynamic>[];

    return SearchResultModel(
      hits: hitsList,
      totalHits: meta['total'] as int? ?? hitsList.length,
      page: meta['page'] as int? ?? 1,
      limit: meta['limit'] as int? ?? 20,
      processingTimeMs: meta['processing_time_ms'] as int? ?? 0,
    );
  }

  Future<SearchResultModel> searchTeachers({
    required String query,
    String? subject,
    String? wilaya,
    String? level,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.dio.get(
      ApiConstants.searchTeachers,
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (wilaya != null && wilaya.isNotEmpty) 'wilaya': wilaya,
        if (level != null && level.isNotEmpty) 'level': level,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        'page': page,
        'limit': limit,
      },
    );
    return _parseSearchResponse(response.data);
  }

  Future<SearchResultModel> searchCourses({
    required String query,
    String? subject,
    String? level,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.dio.get(
      ApiConstants.searchCourses,
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (level != null && level.isNotEmpty) 'level': level,
        'page': page,
        'limit': limit,
      },
    );
    return _parseSearchResponse(response.data);
  }
}
