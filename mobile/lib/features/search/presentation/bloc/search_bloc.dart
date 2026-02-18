import 'package:educonnect/core/network/api_error_handler.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/search/domain/entities/search_result.dart';
import 'package:educonnect/features/search/domain/repositories/search_repository.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchTeachersRequested extends SearchEvent {
  final String query;
  final String? subject;
  final String? wilaya;
  final String? level;
  final double? minPrice;
  final double? maxPrice;
  final int page;

  const SearchTeachersRequested({
    required this.query,
    this.subject,
    this.wilaya,
    this.level,
    this.minPrice,
    this.maxPrice,
    this.page = 1,
  });

  @override
  List<Object?> get props =>
      [query, subject, wilaya, level, minPrice, maxPrice, page];
}

class SearchCoursesRequested extends SearchEvent {
  final String query;
  final String? subject;
  final String? level;
  final int page;

  const SearchCoursesRequested({
    required this.query,
    this.subject,
    this.level,
    this.page = 1,
  });

  @override
  List<Object?> get props => [query, subject, level, page];
}

class SearchCleared extends SearchEvent {}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class SearchState extends Equatable {
  const SearchState();
  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchTeachersLoaded extends SearchState {
  final SearchResult result;
  const SearchTeachersLoaded({required this.result});
  @override
  List<Object?> get props => [result];
}

class SearchCoursesLoaded extends SearchState {
  final SearchResult result;
  const SearchCoursesLoaded({required this.result});
  @override
  List<Object?> get props => [result];
}

class SearchError extends SearchState {
  final String message;
  const SearchError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository searchRepository;

  SearchBloc({required this.searchRepository}) : super(SearchInitial()) {
    on<SearchTeachersRequested>(_onSearchTeachers);
    on<SearchCoursesRequested>(_onSearchCourses);
    on<SearchCleared>(_onSearchCleared);
  }

  Future<void> _onSearchTeachers(
    SearchTeachersRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(SearchLoading());
    try {
      final result = await searchRepository.searchTeachers(
        query: event.query,
        subject: event.subject,
        wilaya: event.wilaya,
        level: event.level,
        minPrice: event.minPrice,
        maxPrice: event.maxPrice,
        page: event.page,
      );
      emit(SearchTeachersLoaded(result: result));
    } catch (e) {
      emit(SearchError(message: _extractError(e)));
    }
  }

  Future<void> _onSearchCourses(
    SearchCoursesRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(SearchLoading());
    try {
      final result = await searchRepository.searchCourses(
        query: event.query,
        subject: event.subject,
        level: event.level,
        page: event.page,
      );
      emit(SearchCoursesLoaded(result: result));
    } catch (e) {
      emit(SearchError(message: _extractError(e)));
    }
  }

  void _onSearchCleared(SearchCleared event, Emitter<SearchState> emit) {
    emit(SearchInitial());
  }

  String _extractError(dynamic e) {
    return extractApiError(e);
  }
}
