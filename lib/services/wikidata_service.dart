import 'package:dio/dio.dart';
import '../models/urof_object.dart';

class WikidataService {
  final Dio _dio = Dio();

  Future<UrofObject?> resolveText(String text) async {
    try {
      final String trimmedText = text.trim();
      if (trimmedText.isEmpty) return null;

      // 1. Search for entity
      final searchResponse = await _dio.get(
        'https://www.wikidata.org/w/api.php',
        queryParameters: {
          'action': 'wbsearchentities',
          'search': trimmedText,
          'language': 'fr',
          'format': 'json',
          'uselang': 'fr',
        },
      );

      final searchResults = searchResponse.data['search'];
      if (searchResults == null || searchResults.isEmpty) {
        return null;
      }

      final firstResult = searchResults[0];
      final String id = firstResult['id'];
      final String searchLabel = firstResult['label'] ?? trimmedText;
      final String searchDesc = firstResult['description'] ?? '';

      // 2. Fetch full entity details
      final entityResponse = await _dio.get(
        'https://www.wikidata.org/w/api.php',
        queryParameters: {
          'action': 'wbgetentities',
          'ids': id,
          'languages': 'fr',
          'format': 'json',
          'uselang': 'fr',
        },
      );

      final entityData = entityResponse.data['entities']?[id];
      if (entityData == null) return null;

      final String label = entityData['labels']?['fr']?['value'] ?? searchLabel;
      final String desc = entityData['descriptions']?['fr']?['value'] ?? searchDesc;

      // Extract image filename
      String? imageUrl;
      final imageClaim = entityData['claims']?['P18']?[0];
      if (imageClaim != null) {
        final filename = imageClaim['mainsnak']?['datavalue']?['value'];
        if (filename is String) {
          imageUrl = 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(filename)}';
        }
      }

      // Determine the type from P31 (Instance of)
      String type = 'unknown';
      final p31Claims = entityData['claims']?['P31'] ?? [];
      final List<String> instanceOfIds = [];
      for (var claim in p31Claims) {
        final idVal = claim['mainsnak']?['datavalue']?['value']?['id'];
        if (idVal is String) {
          instanceOfIds.add(idVal);
        }
      }

      // Check types mapping
      if (instanceOfIds.contains('Q5')) {
        type = 'person';
      } else if (instanceOfIds.any((id) => ['Q515', 'Q1549591', 'Q486971', 'Q3957'].contains(id))) {
        type = 'city';
      } else if (instanceOfIds.contains('Q11424')) {
        type = 'movie';
      } else if (instanceOfIds.contains('Q571')) {
        type = 'book';
      } else if (instanceOfIds.contains('Q729') || instanceOfIds.any((id) => id.startsWith('Q19'))) {
        // Animal / Taxon
        type = 'animal';
      }

      final Map<String, String> attributes = {};

      // Helper to fetch label of another entity (e.g. country, director)
      Future<String?> getEntityLabel(String entityId) async {
        try {
          final res = await _dio.get(
            'https://www.wikidata.org/w/api.php',
            queryParameters: {
              'action': 'wbgetentities',
              'ids': entityId,
              'props': 'labels',
              'languages': 'fr',
              'format': 'json',
            },
          );
          return res.data['entities']?[entityId]?['labels']?['fr']?['value'];
        } catch (_) {
          return null;
        }
      }

      // Collect specific properties based on type
      if (type == 'person') {
        // P569 (Birthdate)
        final birthClaim = entityData['claims']?['P569']?[0];
        final birthTime = birthClaim['mainsnak']?['datavalue']?['value']?['time'];
        if (birthTime is String) {
          attributes['Naissance'] = _cleanWikidataDate(birthTime);
        }

        // P106 (Occupation)
        final occClaims = entityData['claims']?['P106'] ?? [];
        final List<String> occupations = [];
        for (var claim in occClaims.take(3)) {
          final occId = claim['mainsnak']?['datavalue']?['value']?['id'];
          if (occId is String) {
            final occLabel = await getEntityLabel(occId);
            if (occLabel != null) occupations.add(occLabel);
          }
        }
        if (occupations.isNotEmpty) {
          attributes['Activité'] = occupations.join(', ');
        }

        // P19 (Place of birth)
        final birthPlaceClaim = entityData['claims']?['P19']?[0];
        final birthPlaceId = birthPlaceClaim['mainsnak']?['datavalue']?['value']?['id'];
        if (birthPlaceId is String) {
          final placeLabel = await getEntityLabel(birthPlaceId);
          if (placeLabel != null) {
            attributes['Lieu de naissance'] = placeLabel;
          }
        }
      } else if (type == 'city') {
        // P17 (Country)
        final countryClaim = entityData['claims']?['P17']?[0];
        final countryId = countryClaim['mainsnak']?['datavalue']?['value']?['id'];
        if (countryId is String) {
          final countryLabel = await getEntityLabel(countryId);
          if (countryLabel != null) {
            attributes['Pays'] = countryLabel;
          }
        }

        // P1082 (Population)
        final popClaim = entityData['claims']?['P1082']?[0];
        final popVal = popClaim['mainsnak']?['datavalue']?['value']?['amount'];
        if (popVal is String) {
          attributes['Population'] = _formatNumber(popVal);
        }

        // P2046 (Area)
        final areaClaim = entityData['claims']?['P2046']?[0];
        final areaVal = areaClaim['mainsnak']?['datavalue']?['value']?['amount'];
        if (areaVal is String) {
          attributes['Superficie'] = '${_formatNumber(areaVal)} km²';
        }
      } else if (type == 'movie') {
        // P57 (Director)
        final dirClaim = entityData['claims']?['P57']?[0];
        final dirId = dirClaim['mainsnak']?['datavalue']?['value']?['id'];
        if (dirId is String) {
          final dirLabel = await getEntityLabel(dirId);
          if (dirLabel != null) {
            attributes['Réalisateur'] = dirLabel;
          }
        }

        // P577 (Publication date)
        final dateClaim = entityData['claims']?['P577']?[0];
        final dateTime = dateClaim['mainsnak']?['datavalue']?['value']?['time'];
        if (dateTime is String) {
          attributes['Sortie'] = _cleanWikidataDate(dateTime);
        }
      } else if (type == 'book') {
        // P50 (Author)
        final authorClaim = entityData['claims']?['P50']?[0];
        final authorId = authorClaim['mainsnak']?['datavalue']?['value']?['id'];
        if (authorId is String) {
          final authorLabel = await getEntityLabel(authorId);
          if (authorLabel != null) {
            attributes['Auteur'] = authorLabel;
          }
        }

        // P577 (Publication date)
        final dateClaim = entityData['claims']?['P577']?[0];
        final dateTime = dateClaim['mainsnak']?['datavalue']?['value']?['time'];
        if (dateTime is String) {
          attributes['Publication'] = _cleanWikidataDate(dateTime);
        }
      }

      return UrofObject(
        id: id,
        title: label,
        type: type,
        description: desc,
        imageUrl: imageUrl,
        attributes: attributes,
        sourceUrl: 'https://www.wikidata.org/wiki/$id',
      );
    } catch (e) {
      print('Wikidata resolution error: $e');
      return null;
    }
  }

  String _cleanWikidataDate(String dateStr) {
    // Wikidata date formats look like "+1995-12-14T00:00:00Z"
    if (dateStr.startsWith('+')) {
      dateStr = dateStr.substring(1);
    }
    final tIdx = dateStr.indexOf('T');
    if (tIdx != -1) {
      dateStr = dateStr.substring(0, tIdx);
    }
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      // Return DD/MM/YYYY
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateStr;
  }

  String _formatNumber(String numStr) {
    // Removes leading '+' sign and cleans float format
    if (numStr.startsWith('+')) {
      numStr = numStr.substring(1);
    }
    final doubleVal = double.tryParse(numStr);
    if (doubleVal != null) {
      if (doubleVal == doubleVal.roundToDouble()) {
        return doubleVal.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
      }
      return doubleVal.toStringAsFixed(2);
    }
    return numStr;
  }
}
