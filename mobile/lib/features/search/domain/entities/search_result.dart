import 'package:equatable/equatable.dart';

class SearchResult extends Equatable {
  final List<dynamic> hits;
  final int totalHits;
  final int page;
  final int limit;
  final int processingTimeMs;

  const SearchResult({
    this.hits = const [],
    this.totalHits = 0,
    this.page = 1,
    this.limit = 20,
    this.processingTimeMs = 0,
  });

  @override
  List<Object?> get props => [totalHits, page, hits];
}
