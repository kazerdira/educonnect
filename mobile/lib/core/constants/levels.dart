import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:flutter/foundation.dart';

/// Algerian education system levels — fetched from backend at runtime.
class Levels {
  Levels._();

  static List<LevelItem> _cached = [];
  static bool _loaded = false;

  /// All levels. Returns the cached list (empty until [load] completes).
  static List<LevelItem> get all => _cached;

  /// Whether levels have been loaded from the API.
  static bool get isLoaded => _loaded;

  /// Fetch levels from GET /levels and cache them.
  /// Safe to call multiple times — only the first successful call fetches.
  static Future<void> load(ApiClient apiClient) async {
    if (_loaded) return;
    try {
      final response = await apiClient.dio.get(ApiConstants.levels);
      final data = response.data['data'] as List<dynamic>? ?? [];
      _cached = data
          .map((e) => LevelItem(
                code: e['id'] as String? ?? '',
                name: e['name'] as String? ?? '',
                cycle: e['cycle'] as String? ?? '',
              ))
          .toList();
      _loaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Levels] Failed to load: $e');
    }
  }

  /// Force a reload (e.g. after admin updates levels).
  static Future<void> reload(ApiClient apiClient) async {
    _loaded = false;
    _cached = [];
    await load(apiClient);
  }

  /// Get levels by cycle.
  static List<LevelItem> byCycle(String cycle) =>
      _cached.where((l) => l.cycle == cycle).toList();

  /// Just the codes (UUIDs) for dropdown values.
  static List<String> get codes => _cached.map((l) => l.code).toList();

  /// Map of code (UUID) → display name.
  static Map<String, String> get codeToName =>
      {for (var l in _cached) l.code: l.name};
}

/// A single education level.
class LevelItem {
  final String code; // UUID from database
  final String name; // e.g. "1ère Année Moyenne"
  final String cycle; // "primaire" | "moyen" | "secondaire"

  const LevelItem({
    required this.code,
    required this.name,
    required this.cycle,
  });
}
