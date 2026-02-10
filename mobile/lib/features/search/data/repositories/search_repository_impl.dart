import 'package:educonnect/features/search/data/datasources/search_remote_datasource.dart';
import 'package:educonnect/features/search/domain/entities/search_result.dart';
import 'package:educonnect/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl({required this.remoteDataSource});

  @override
  Future<SearchResult> searchTeachers({
    required String query,
    String? subject,
    String? wilaya,
    String? level,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int limit = 20,
  }) {
    return remoteDataSource.searchTeachers(
      query: query,
      subject: subject,
      wilaya: wilaya,
      level: level,
      minPrice: minPrice,
      maxPrice: maxPrice,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<SearchResult> searchCourses({
    required String query,
    String? subject,
    String? level,
    int page = 1,
    int limit = 20,
  }) {
    return remoteDataSource.searchCourses(
      query: query,
      subject: subject,
      level: level,
      page: page,
      limit: limit,
    );
  }
}
