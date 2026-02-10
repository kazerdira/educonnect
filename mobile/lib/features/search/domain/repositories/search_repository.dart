import 'package:educonnect/features/search/domain/entities/search_result.dart';

abstract class SearchRepository {
  Future<SearchResult> searchTeachers({
    required String query,
    String? subject,
    String? wilaya,
    String? level,
    double? minPrice,
    double? maxPrice,
    int page,
    int limit,
  });

  Future<SearchResult> searchCourses({
    required String query,
    String? subject,
    String? level,
    int page,
    int limit,
  });
}
