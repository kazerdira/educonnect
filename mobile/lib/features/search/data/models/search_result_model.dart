import 'package:educonnect/features/search/domain/entities/search_result.dart';

class SearchResultModel extends SearchResult {
  const SearchResultModel({
    super.hits,
    super.totalHits,
    super.page,
    super.limit,
    super.processingTimeMs,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      hits: json['hits'] as List<dynamic>? ?? [],
      totalHits: json['total_hits'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      processingTimeMs: json['processing_time_ms'] as int? ?? 0,
    );
  }
}
