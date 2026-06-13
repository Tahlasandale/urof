import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/urof_object.dart';

/// Cache service for storing resolved UROF objects locally.
///
/// Uses Hive to persist UROF lookups and avoid redundant network requests.
/// Each entry has a configurable TTL (default: 24 hours).
class CacheService {
  static const String _boxName = 'urof_cache';
  static const Duration _defaultTtl = Duration(hours: 24);

  late Box<String> _box;
  bool _initialized = false;

  /// Initialize the Hive box. Must be called before any cache operations.
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  /// Check if the box is ready.
  bool get isInitialized => _initialized;

  /// Store a resolved [UrofObject] in the cache keyed by [text].
  Future<void> put(String text, UrofObject object) async {
    if (!_initialized) return;
    final key = _normalizeKey(text);
    final entry = _CacheEntry(
      object: object,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _box.put(key, jsonEncode(entry.toJson()));
  }

  /// Retrieve a cached [UrofObject] for [text], or null if not found or expired.
  UrofObject? get(String text) {
    if (!_initialized) return null;
    final key = _normalizeKey(text);
    final raw = _box.get(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(decoded);

      // Check TTL
      final age = DateTime.now().millisecondsSinceEpoch - entry.timestamp;
      if (age > _defaultTtl.inMilliseconds) {
        // Expired — remove from cache
        _box.delete(key);
        return null;
      }

      return entry.object;
    } catch (e) {
      print('CacheService: error reading entry for "$text": $e');
      _box.delete(key);
      return null;
    }
  }

  /// Check if a valid (non-expired) cache entry exists for [text].
  bool has(String text) {
    return get(text) != null;
  }

  /// Remove a specific cache entry.
  Future<void> remove(String text) async {
    if (!_initialized) return;
    await _box.delete(_normalizeKey(text));
  }

  /// Clear all cached entries.
  Future<void> clear() async {
    if (!_initialized) return;
    await _box.clear();
  }

  /// Get the number of cached entries.
  int get count {
    if (!_initialized) return 0;
    return _box.length;
  }

  String _normalizeKey(String text) {
    return text.trim().toLowerCase();
  }
}

/// Internal model for a cache entry with TTL tracking.
class _CacheEntry {
  final UrofObject object;
  final int timestamp;

  const _CacheEntry({
    required this.object,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'object': {
          'id': object.id,
          'title': object.title,
          'type': object.type,
          'description': object.description,
          'imageUrl': object.imageUrl,
          'attributes': object.attributes,
          'sourceUrl': object.sourceUrl,
        },
        'timestamp': timestamp,
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    final objJson = json['object'] as Map<String, dynamic>;
    final attributes = (objJson['attributes'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        <String, String>{};

    return _CacheEntry(
      object: UrofObject(
        id: objJson['id']?.toString() ?? '',
        title: objJson['title']?.toString() ?? '',
        type: objJson['type']?.toString() ?? 'unknown',
        description: objJson['description']?.toString() ?? '',
        imageUrl: objJson['imageUrl']?.toString(),
        attributes: attributes,
        sourceUrl: objJson['sourceUrl']?.toString(),
      ),
      timestamp: json['timestamp'] as int,
    );
  }
}
