import 'package:dio/dio.dart';

class MusicBrainzService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    headers: {
      'User-Agent': 'UROF/1.0 (urof-app)',
    },
  ));

  /// Cherche un artiste par nom.
  /// Endpoint: GET /ws/2/artist?query=...&fmt=json&limit=5
  Future<Map<String, dynamic>?> searchArtist(String query) async {
    try {
      final response = await _dio.get(
        'https://musicbrainz.org/ws/2/artist',
        queryParameters: {
          'query': query,
          'fmt': 'json',
          'limit': 5,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      // ignore: avoid_print
      print('MusicBrainzService error: $e');
    }
    return null;
  }

  /// Récupère les détails d'un artiste par son MBID (MusicBrainz Identifier).
  /// Endpoint: GET /ws/2/artist/`mbid`?fmt=json&inc=tags+ratings
  Future<Map<String, dynamic>?> fetchArtistDetails(String mbid) async {
    try {
      final response = await _dio.get(
        'https://musicbrainz.org/ws/2/artist/$mbid',
        queryParameters: {
          'fmt': 'json',
          'inc': 'tags+ratings',
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      // ignore: avoid_print
      print('MusicBrainzService error: $e');
    }
    return null;
  }
}

