import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:flutter/foundation.dart';

/// Algerian education system subjects — fetched from backend at runtime.
class Subjects {
  Subjects._();

  static List<SubjectItem> _cached = [];
  static bool _loaded = false;

  /// All subjects. Returns the cached list (empty until [load] completes).
  static List<SubjectItem> get all => _cached;

  /// Whether subjects have been loaded from the API.
  static bool get isLoaded => _loaded;

  /// Fetch subjects from GET /subjects and cache them.
  /// Safe to call multiple times — only the first successful call fetches.
  static Future<void> load(ApiClient apiClient) async {
    if (_loaded) return;
    try {
      final response = await apiClient.dio.get(ApiConstants.subjects);
      final data = response.data['data'] as List<dynamic>? ?? [];
      _cached = data
          .map((e) => SubjectItem(
                id: e['id'] as String? ?? '',
                name: e['name_fr'] as String? ?? e['name'] as String? ?? '',
                category: e['category'] as String? ?? '',
              ))
          .toList();
      _loaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Subjects] Failed to load: $e');
    }
  }

  /// Force a reload.
  static Future<void> reload(ApiClient apiClient) async {
    _loaded = false;
    _cached = [];
    await load(apiClient);
  }

  /// Get subjects by category.
  static List<SubjectItem> byCategory(String category) =>
      _cached.where((s) => s.category == category).toList();

  /// Find subject by ID.
  static SubjectItem? findById(String id) {
    try {
      return _cached.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Map of ID → name.
  static Map<String, String> get idToName =>
      {for (var s in _cached) s.id: s.name};
}

/// A single subject.
class SubjectItem {
  final String id;
  final String name;
  final String category;

  const SubjectItem({
    required this.id,
    required this.name,
    required this.category,
  });
}
