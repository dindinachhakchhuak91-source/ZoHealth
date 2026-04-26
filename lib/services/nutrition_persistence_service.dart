import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class NutritionPersistenceService {
  NutritionPersistenceService._();

  static final NutritionPersistenceService instance =
      NutritionPersistenceService._();

  static const String _calculatorPrefsPrefix = 'nutrition_calculator_state_';
  static const String _trackerPrefsPrefix = 'nutrition_tracker_entries_';
  static const String _mealPlanPrefsPrefix = 'nutrition_meal_plan_';
  static const String _growthTrackerPrefsPrefix = 'growth_tracker_state_';
  static const String _micronutritionPrefsPrefix = 'micronutrition_tracker_state_';
  static const String _trackedProfilesPrefsPrefix = 'tracked_profiles_state_';

  Future<Map<String, dynamic>?> loadCalculatorState(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadPreferredJsonMap(
      prefs: prefs,
      userId: userId,
      keyBuilder: _calculatorPrefsKey,
    );

    if (userId == null || userId.isEmpty) {
      return local;
    }

    try {
      final rows = await SupabaseService.instance.select(
        'nutrition_calculator_states',
      );
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['user_id']?.toString() == userId,
            orElse: () => null,
          );
      final remote = _payloadAsMap(row?['payload']);
      if (remote != null) {
        await prefs.setString(_calculatorPrefsKey(userId), jsonEncode(remote));
        return remote;
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveCalculatorState(
    String? userId,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calculatorPrefsKey(userId), jsonEncode(payload));

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await SupabaseService.instance.upsert(
        'nutrition_calculator_states',
        {
          'user_id': userId,
          'payload': payload,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadTrackerEntries(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadPreferredJsonList(
      prefs: prefs,
      userId: userId,
      keyBuilder: _trackerPrefsKey,
    );

    if (userId == null || userId.isEmpty) {
      return local;
    }

    try {
      final rows = await SupabaseService.instance.select('nutrition_tracker_entries');
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['user_id']?.toString() == userId,
            orElse: () => null,
          );
      final remote = _payloadAsList(row?['payload']);
      if (remote != null) {
        await prefs.setString(_trackerPrefsKey(userId), jsonEncode(remote));
        return remote;
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveTrackerEntries(
    String? userId,
    List<Map<String, dynamic>> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trackerPrefsKey(userId), jsonEncode(payload));

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await SupabaseService.instance.upsert(
        'nutrition_tracker_entries',
        {
          'user_id': userId,
          'payload': payload,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadMealPlanEntries(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadPreferredJsonList(
      prefs: prefs,
      userId: userId,
      keyBuilder: _mealPlanPrefsKey,
    );

    if (userId == null || userId.isEmpty) {
      return local;
    }

    try {
      final rows = await SupabaseService.instance.select('nutrition_meal_plans');
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['user_id']?.toString() == userId,
            orElse: () => null,
          );
      final remote = _payloadAsList(row?['payload']);
      if (remote != null) {
        await prefs.setString(_mealPlanPrefsKey(userId), jsonEncode(remote));
        return remote;
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveMealPlanEntries(
    String? userId,
    List<Map<String, dynamic>> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mealPlanPrefsKey(userId), jsonEncode(payload));

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await SupabaseService.instance.upsert(
        'nutrition_meal_plans',
        {
          'user_id': userId,
          'payload': payload,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadGrowthTrackerState(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadPreferredJsonMap(
      prefs: prefs,
      userId: userId,
      keyBuilder: _growthTrackerPrefsKey,
    );

    if (userId == null || userId.isEmpty) {
      return local;
    }

    try {
      final rows = await SupabaseService.instance.select('growth_tracker_states');
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['user_id']?.toString() == userId,
            orElse: () => null,
          );
      final remote = _payloadAsMap(row?['payload']);
      if (remote != null) {
        await prefs.setString(_growthTrackerPrefsKey(userId), jsonEncode(remote));
        return remote;
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveGrowthTrackerState(
    String? userId,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_growthTrackerPrefsKey(userId), jsonEncode(payload));

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await SupabaseService.instance.upsert(
        'growth_tracker_states',
        {
          'user_id': userId,
          'payload': payload,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadMicronutritionTrackerState(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadPreferredJsonMap(
      prefs: prefs,
      userId: userId,
      keyBuilder: _micronutritionPrefsKey,
    );

    if (userId == null || userId.isEmpty) {
      return local;
    }

    try {
      final rows = await SupabaseService.instance.select('micronutrition_tracker_states');
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['user_id']?.toString() == userId,
            orElse: () => null,
          );
      final remote = _payloadAsMap(row?['payload']);
      if (remote != null) {
        await prefs.setString(_micronutritionPrefsKey(userId), jsonEncode(remote));
        return remote;
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveMicronutritionTrackerState(
    String? userId,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_micronutritionPrefsKey(userId), jsonEncode(payload));

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await SupabaseService.instance.upsert(
        'micronutrition_tracker_states',
        {
          'user_id': userId,
          'payload': payload,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadTrackedProfilesState(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadPreferredJsonMap(
      prefs: prefs,
      userId: userId,
      keyBuilder: _trackedProfilesPrefsKey,
    );

    if (userId == null || userId.isEmpty) {
      return local;
    }

    try {
      final growthState = await loadGrowthTrackerState(userId);
      final remote = growthState == null
          ? null
          : <String, dynamic>{
              'tracked_profiles': growthState['tracked_profiles'] ?? const [],
              'selected_profile_id': growthState['selected_profile_id'],
            };
      if (remote != null) {
        await prefs.setString(_trackedProfilesPrefsKey(userId), jsonEncode(remote));
        return remote;
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveTrackedProfilesState(
    String? userId,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trackedProfilesPrefsKey(userId), jsonEncode(payload));

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final existing = await loadGrowthTrackerState(userId) ?? <String, dynamic>{};
      final merged = Map<String, dynamic>.from(existing)..addAll(payload);
      await saveGrowthTrackerState(userId, merged);
    } catch (_) {}
  }

  String _calculatorPrefsKey(String? userId) =>
      '$_calculatorPrefsPrefix${userId ?? 'guest'}';

  String _trackerPrefsKey(String? userId) =>
      '$_trackerPrefsPrefix${userId ?? 'guest'}';

  String _mealPlanPrefsKey(String? userId) =>
      '$_mealPlanPrefsPrefix${userId ?? 'guest'}';

  String _growthTrackerPrefsKey(String? userId) =>
      '$_growthTrackerPrefsPrefix${userId ?? 'guest'}';

  String _micronutritionPrefsKey(String? userId) =>
      '$_micronutritionPrefsPrefix${userId ?? 'guest'}';

  String _trackedProfilesPrefsKey(String? userId) =>
      '$_trackedProfilesPrefsPrefix${userId ?? 'guest'}';

  Map<String, dynamic>? _loadPreferredJsonMap({
    required SharedPreferences prefs,
    required String? userId,
    required String Function(String? userId) keyBuilder,
  }) {
    final local = _loadJsonMap(prefs.getString(keyBuilder(userId)));
    if (local != null || userId == null || userId.isEmpty) {
      return local;
    }

    final guest = _loadJsonMap(prefs.getString(keyBuilder(null)));
    if (guest != null) {
      prefs.setString(keyBuilder(userId), jsonEncode(guest));
    }
    return guest;
  }

  List<Map<String, dynamic>> _loadPreferredJsonList({
    required SharedPreferences prefs,
    required String? userId,
    required String Function(String? userId) keyBuilder,
  }) {
    final local = _loadJsonList(prefs.getString(keyBuilder(userId)));
    if (local.isNotEmpty || userId == null || userId.isEmpty) {
      return local;
    }

    final guest = _loadJsonList(prefs.getString(keyBuilder(null)));
    if (guest.isNotEmpty) {
      prefs.setString(keyBuilder(userId), jsonEncode(guest));
    }
    return guest;
  }

  Map<String, dynamic>? _loadJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  List<Map<String, dynamic>> _loadJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Map<String, dynamic>? _payloadAsMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    if (payload is String) return _loadJsonMap(payload);
    return null;
  }

  List<Map<String, dynamic>>? _payloadAsList(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    }
    if (payload is String) return _loadJsonList(payload);
    return null;
  }
}
