import 'package:dio/dio.dart';

class OpenLibraryService {
  final Dio _dio = Dio();

  /// Fetches rich details for a book from OpenLibrary by ISBN or Open Library ID (OLID).
  /// Returns a map with additional attributes and optionally a cover image URL.
  Future<Map<String, dynamic>?> fetchBookData({String? isbn, String? olid}) async {
    try {
      String? key;
      if (isbn != null) {
        // Clean ISBN from spaces or hyphens
        final cleanIsbn = isbn.replaceAll(RegExp(r'[\s\-]'), '').trim();
        if (cleanIsbn.isNotEmpty) {
          key = 'ISBN:$cleanIsbn';
        }
      } else if (olid != null) {
        final cleanOlid = olid.trim();
        if (cleanOlid.isNotEmpty) {
          key = 'OLID:$cleanOlid';
        }
      }

      if (key == null) return null;

      final response = await _dio.get(
        'https://openlibrary.org/api/books',
        queryParameters: {
          'bibkeys': key,
          'format': 'json',
          'jscmd': 'data',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      final data = response.data[key];
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (e) {
      print('OpenLibraryService error: $e');
    }
    return null;
  }
}
