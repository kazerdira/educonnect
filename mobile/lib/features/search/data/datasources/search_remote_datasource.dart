import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/search/data/models/search_result_model.dart';

class SearchRemoteDataSource {
  final ApiClient apiClient;

  SearchRemoteDataSource({required this.apiClient});

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
        'q': query,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (wilaya != null && wilaya.isNotEmpty) 'wilaya': wilaya,
        if (level != null && level.isNotEmpty) 'level': level,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        'page': page,
        'limit': limit,
      },
    );
    final raw = response.data['data'];
    if (raw == null) return const SearchResultModel();
    if (raw is List) {
      return SearchResultModel(hits: raw, totalHits: raw.length);
    }
    if (raw is Map<String, dynamic>) {
      return SearchResultModel.fromJson(raw);
    }
    return const SearchResultModel();
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
        'q': query,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (level != null && level.isNotEmpty) 'level': level,
        'page': page,
        'limit': limit,
      },
    );
    final raw = response.data['data'];
    if (raw == null) return const SearchResultModel();
    if (raw is List) {
      return SearchResultModel(hits: raw, totalHits: raw.length);
    }
    if (raw is Map<String, dynamic>) {
      return SearchResultModel.fromJson(raw);
    }
    return const SearchResultModel();
  }
}
