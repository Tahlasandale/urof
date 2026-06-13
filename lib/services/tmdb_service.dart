import 'package:dio/dio.dart';

class TmdbService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
  ));
  
  // The API key can be supplied via compiler flag --dart-define=TMDB_API_KEY=your_key
  static const String _envApiKey = String.fromEnvironment('TMDB_API_KEY');
  
  final String? _customApiKey;

  TmdbService({String? apiKey}) : _customApiKey = apiKey;

  String? get _apiKey {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey;
    }
    if (_envApiKey.isNotEmpty) {
      return _envApiKey;
    }
    return null;
  }

  bool get hasApiKey => _apiKey != null;

  /// Fetches movie or TV show details from TMDb.
  /// [type] can be 'movie' or 'tv'.
  Future<Map<String, dynamic>?> fetchMediaDetails(String tmdbId, String type) async {
    final key = _apiKey;
    if (key == null) return null;

    try {
      final endpoint = type == 'tv' ? 'tv' : 'movie';
      final response = await _dio.get(
        'https://api.themoviedb.org/3/$endpoint/$tmdbId',
        queryParameters: {
          'api_key': key,
          'language': 'fr-FR',
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      print('TmdbService error: $e');
    }
    return null;
  }

  /// Search movies by title.
  Future<Map<String, dynamic>?> searchMovie(String query) async {
    final key = _apiKey;
    if (key == null) return null;

    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/search/movie',
        queryParameters: {
          'api_key': key,
          'query': query,
          'language': 'fr-FR',
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      print('TmdbService error: $e');
    }
    return null;
  }

  /// Search TV shows by title.
  Future<Map<String, dynamic>?> searchTv(String query) async {
    final key = _apiKey;
    if (key == null) return null;

    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/search/tv',
        queryParameters: {
          'api_key': key,
          'query': query,
          'language': 'fr-FR',
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      print('TmdbService error: $e');
    }
    return null;
  }

  /// Build full poster URL from relative path.
  String? getPosterUrl(String? path, {int width = 500}) {
    if (path == null || path.isEmpty) return null;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return 'https://image.tmdb.org/t/p/w$width$cleanPath';
  }
}
