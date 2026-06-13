import 'package:dio/dio.dart';

class OpenLibraryService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
  ));

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
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey(key)) {
        final bookData = data[key];
        if (bookData is Map<String, dynamic>) {
          return bookData;
        }
      }
    } catch (e) {
      print('OpenLibraryService error: $e');
    }
    return null;
  }

  /// Searches books by title/author using the OpenLibrary search API.
  Future<Map<String, dynamic>?> searchBook(String query) async {
    try {
      final response = await _dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: {
          'q': query,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      print('OpenLibraryService error: $e');
    }
    return null;
  }

  /// Builds a cover URL from an Open Library ID (OLID).
  /// Supported sizes: S, M, L. Defaults to M.
  String? getCoverUrl(String? olid, {String size = 'M'}) {
    if (olid == null || olid.trim().isEmpty) return null;
    return 'https://covers.openlibrary.org/b/olid/${olid.trim()}-$size.jpg';
  }

  /// Builds a cover URL from an ISBN.
  /// Supported sizes: S, M, L. Defaults to M.
  String? getCoverUrlByIsbn(String? isbn, {String size = 'M'}) {
    if (isbn == null || isbn.trim().isEmpty) return null;
    final cleanIsbn = isbn.replaceAll(RegExp(r'[\s\-]'), '').trim();
    if (cleanIsbn.isEmpty) return null;
    return 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-$size.jpg';
  }

  /// Parses raw searched book data (typically a document from searchBook results)
  /// into a clean map containing: title, author, isbn, olid, publishYear, numberOfPages, subjects, coverUrl.
  Map<String, dynamic> extractBookData(Map<String, dynamic> rawData) {
    // 1. Title
    final String? title = rawData['title']?.toString();

    // 2. Author
    String? author;
    if (rawData['author_name'] is List) {
      final List authors = rawData['author_name'] as List;
      if (authors.isNotEmpty) {
        author = authors.map((a) => a.toString()).join(', ');
      }
    } else if (rawData['author_name'] != null) {
      author = rawData['author_name'].toString();
    }

    // 3. ISBN
    String? isbn;
    if (rawData['isbn'] is List) {
      final List isbns = rawData['isbn'] as List;
      if (isbns.isNotEmpty) {
        isbn = isbns.first.toString();
      }
    } else if (rawData['isbn'] != null) {
      isbn = rawData['isbn'].toString();
    }

    // 4. OLID
    String? olid;
    if (rawData['cover_edition_key'] != null) {
      olid = rawData['cover_edition_key'].toString();
    } else if (rawData['edition_key'] is List) {
      final List editions = rawData['edition_key'] as List;
      if (editions.isNotEmpty) {
        olid = editions.first.toString();
      }
    } else if (rawData['key'] != null) {
      final keyStr = rawData['key'].toString();
      final parts = keyStr.split('/');
      if (parts.isNotEmpty) {
        final lastPart = parts.last;
        // Check if it looks like an OLID or work ID
        if (lastPart.startsWith('OL')) {
          olid = lastPart;
        }
      }
    }

    // 5. Publish Year
    int? publishYear;
    if (rawData['first_publish_year'] != null) {
      publishYear = int.tryParse(rawData['first_publish_year'].toString());
    } else if (rawData['publish_year'] is List) {
      final List years = rawData['publish_year'] as List;
      if (years.isNotEmpty) {
        publishYear = int.tryParse(years.first.toString());
      }
    }

    // 6. Number of Pages
    int? numberOfPages;
    if (rawData['number_of_pages_median'] != null) {
      numberOfPages = int.tryParse(rawData['number_of_pages_median'].toString());
    } else if (rawData['number_of_pages'] != null) {
      numberOfPages = int.tryParse(rawData['number_of_pages'].toString());
    }

    // 7. Subjects
    List<String>? subjects;
    if (rawData['subject'] is List) {
      subjects = (rawData['subject'] as List).map((s) => s.toString()).toList();
    } else if (rawData['subjects'] is List) {
      subjects = (rawData['subjects'] as List).map((s) => s.toString()).toList();
    }

    // 8. Cover URL
    String? coverUrl;
    if (olid != null) {
      coverUrl = getCoverUrl(olid, size: 'L');
    } else if (isbn != null) {
      coverUrl = getCoverUrlByIsbn(isbn, size: 'L');
    }

    return {
      'title': title,
      'author': author,
      'isbn': isbn,
      'olid': olid,
      'publishYear': publishYear,
      'numberOfPages': numberOfPages,
      'subjects': subjects,
      'coverUrl': coverUrl,
    };
  }
}
