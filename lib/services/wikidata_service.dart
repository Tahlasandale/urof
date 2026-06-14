import 'package:dio/dio.dart';
import '../models/urof_object.dart';
import 'cache_service.dart';
import 'openlibrary_service.dart';
import 'tmdb_service.dart';

class WikidataService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final _openLibraryService = OpenLibraryService();
  final _tmdbService = TmdbService();
  final CacheService _cacheService;

  WikidataService({CacheService? cacheService})
      : _cacheService = cacheService ?? CacheService();

  Future<UrofObject?> resolveText(String text) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) return null;
    final String normalizedText = _normalizeSearchText(trimmedText);
    try {

      // Check cache first (using normalized text as key)
      final cached = _cacheService.get(normalizedText);
      if (cached != null) {
        print('WikidataService: cache hit for "$trimmedText"');
        return cached;
      }

      // 1. Search for entity
      final searchResponse = await _dio.get(
        'https://www.wikidata.org/w/api.php',
        queryParameters: {
          'action': 'wbsearchentities',
          'search': normalizedText,
          'language': 'fr',
          'format': 'json',
          'uselang': 'fr',
        },
      );

      final searchResults = searchResponse.data['search'];
      if (searchResults == null || searchResults.isEmpty) {
        print('WikidataService: no search results for "$trimmedText"');
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

      String label = entityData['labels']?['fr']?['value'] ?? searchLabel;
      String desc = entityData['descriptions']?['fr']?['value'] ?? searchDesc;

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

      // Check types mapping (added TV series and anime to movie type, and taxon/species to animal type)
      if (instanceOfIds.contains('Q5')) {
        type = 'person';
      } else if (instanceOfIds.any((id) => ['Q515', 'Q1549591', 'Q486971', 'Q3957'].contains(id))) {
        type = 'city';
      } else if (instanceOfIds.any((id) => ['Q11424', 'Q5398426', 'Q1107'].contains(id))) {
        type = 'movie';
      } else if (instanceOfIds.contains('Q571')) {
        type = 'book';
      } else if (instanceOfIds.any((id) => ['Q729', 'Q16521', 'Q747462'].contains(id)) || instanceOfIds.any((id) => id.startsWith('Q19'))) {
        type = 'animal';
      }

      // Helper methods to extract claims
      List<String> getClaimEntityIds(String prop, {int limit = 1}) {
        final list = entityData['claims']?[prop] ?? [];
        final List<String> result = [];
        for (var claim in list) {
          if (result.length >= limit) break;
          final idVal = claim['mainsnak']?['datavalue']?['value']?['id'];
          if (idVal is String) {
            result.add(idVal);
          }
        }
        return result;
      }

      String? getClaimStringValue(String prop) {
        final list = entityData['claims']?[prop] ?? [];
        if (list.isEmpty) return null;
        final val = list[0]['mainsnak']?['datavalue']?['value'];
        if (val is String) return val;
        return null;
      }

      String? getClaimTimeValue(String prop) {
        final list = entityData['claims']?[prop] ?? [];
        if (list.isEmpty) return null;
        return list[0]['mainsnak']?['datavalue']?['value']?['time'];
      }

      String? getClaimAmountValue(String prop) {
        final list = entityData['claims']?[prop] ?? [];
        if (list.isEmpty) return null;
        return list[0]['mainsnak']?['datavalue']?['value']?['amount'];
      }

      // Collect referenced entity IDs for batch label resolution
      final List<String> idsToResolve = [];
      if (type == 'person') {
        idsToResolve.addAll(getClaimEntityIds('P19')); // Place of birth
        idsToResolve.addAll(getClaimEntityIds('P20')); // Place of death
        idsToResolve.addAll(getClaimEntityIds('P106', limit: 3)); // Occupation
        idsToResolve.addAll(getClaimEntityIds('P27')); // Citizenship
        idsToResolve.addAll(getClaimEntityIds('P166', limit: 3)); // Awards
      } else if (type == 'city') {
        idsToResolve.addAll(getClaimEntityIds('P17')); // Country
      } else if (type == 'movie') {
        idsToResolve.addAll(getClaimEntityIds('P57')); // Director
        idsToResolve.addAll(getClaimEntityIds('P58')); // Screenwriter
        idsToResolve.addAll(getClaimEntityIds('P161', limit: 5)); // Cast
        idsToResolve.addAll(getClaimEntityIds('P136', limit: 3)); // Genre
        idsToResolve.addAll(getClaimEntityIds('P364')); // Original language
      } else if (type == 'book') {
        idsToResolve.addAll(getClaimEntityIds('P50')); // Author
        idsToResolve.addAll(getClaimEntityIds('P123')); // Publisher
        idsToResolve.addAll(getClaimEntityIds('P136', limit: 3)); // Genre
      } else if (type == 'animal') {
        idsToResolve.addAll(getClaimEntityIds('P171')); // Parent taxon
        idsToResolve.addAll(getClaimEntityIds('P105')); // Taxon rank
        idsToResolve.addAll(getClaimEntityIds('P141')); // Conservation status
      }

      // Fetch all referenced entity labels in a single batch
      final Map<String, String> resolvedLabels = await _getEntityLabels(idsToResolve);
      final Map<String, String> attributes = {};

      if (type == 'person') {
        final birthTime = getClaimTimeValue('P569');
        if (birthTime != null) {
          attributes['Naissance'] = _cleanWikidataDate(birthTime);
        }

        final deathTime = getClaimTimeValue('P570');
        if (deathTime != null) {
          attributes['Décès'] = _cleanWikidataDate(deathTime);
        }

        final birthPlaces = getClaimEntityIds('P19').map((id) => resolvedLabels[id]).whereType<String>();
        if (birthPlaces.isNotEmpty) {
          attributes['Lieu de naissance'] = birthPlaces.join(', ');
        }

        final deathPlaces = getClaimEntityIds('P20').map((id) => resolvedLabels[id]).whereType<String>();
        if (deathPlaces.isNotEmpty) {
          attributes['Lieu de décès'] = deathPlaces.join(', ');
        }

        final occupations = getClaimEntityIds('P106', limit: 3).map((id) => resolvedLabels[id]).whereType<String>();
        if (occupations.isNotEmpty) {
          attributes['Activité'] = occupations.join(', ');
        }

        final citizenships = getClaimEntityIds('P27').map((id) => resolvedLabels[id]).whereType<String>();
        if (citizenships.isNotEmpty) {
          attributes['Nationalité'] = citizenships.join(', ');
        }

        final awards = getClaimEntityIds('P166', limit: 3).map((id) => resolvedLabels[id]).whereType<String>();
        if (awards.isNotEmpty) {
          attributes['Distinctions'] = awards.join(', ');
        }
      } else if (type == 'city') {
        final countries = getClaimEntityIds('P17').map((id) => resolvedLabels[id]).whereType<String>();
        if (countries.isNotEmpty) {
          attributes['Pays'] = countries.join(', ');
        }

        final popVal = getClaimAmountValue('P1082');
        if (popVal != null) {
          attributes['Population'] = _formatNumber(popVal);
        }

        final areaVal = getClaimAmountValue('P2046');
        if (areaVal != null) {
          attributes['Superficie'] = '${_formatNumber(areaVal)} km²';
        }

        final elevVal = getClaimAmountValue('P2044');
        if (elevVal != null) {
          attributes['Altitude'] = '${_formatNumber(elevVal)} m';
        }

        final postalCode = getClaimStringValue('P281');
        if (postalCode != null) {
          attributes['Code postal'] = postalCode;
        }
      } else if (type == 'movie') {
        final directors = getClaimEntityIds('P57').map((id) => resolvedLabels[id]).whereType<String>();
        if (directors.isNotEmpty) {
          attributes['Réalisateur'] = directors.join(', ');
        }

        final writers = getClaimEntityIds('P58').map((id) => resolvedLabels[id]).whereType<String>();
        if (writers.isNotEmpty) {
          attributes['Scénariste'] = writers.join(', ');
        }

        final cast = getClaimEntityIds('P161', limit: 5).map((id) => resolvedLabels[id]).whereType<String>();
        if (cast.isNotEmpty) {
          attributes['Acteurs principaux'] = cast.join(', ');
        }

        final genres = getClaimEntityIds('P136', limit: 3).map((id) => resolvedLabels[id]).whereType<String>();
        if (genres.isNotEmpty) {
          attributes['Genre'] = genres.join(', ');
        }

        final pubTime = getClaimTimeValue('P577');
        if (pubTime != null) {
          attributes['Sortie'] = _cleanWikidataDate(pubTime);
        }

        final durationVal = getClaimAmountValue('P2047');
        if (durationVal != null) {
          attributes['Durée'] = '${_formatNumber(durationVal)} min';
        }

        final lang = getClaimEntityIds('P364').map((id) => resolvedLabels[id]).whereType<String>();
        if (lang.isNotEmpty) {
          attributes['Langue originale'] = lang.join(', ');
        }

        // Try enriching with TMDb if key is configured
        final tmdbMovieId = getClaimStringValue('P9722');
        final tmdbTvId = getClaimStringValue('P9726');
        if ((tmdbMovieId != null || tmdbTvId != null) && _tmdbService.hasApiKey) {
          final isTv = tmdbTvId != null;
          final mediaId = tmdbTvId ?? tmdbMovieId!;
          final tmdbData = await _tmdbService.fetchMediaDetails(mediaId, isTv ? 'tv' : 'movie');
          if (tmdbData != null) {
            final overview = tmdbData['overview'];
            if (overview is String && overview.trim().isNotEmpty) {
              desc = overview;
            }
            final posterPath = tmdbData['poster_path'];
            if (imageUrl == null && posterPath is String && posterPath.isNotEmpty) {
              imageUrl = 'https://image.tmdb.org/t/p/w500$posterPath';
            }
            final rating = tmdbData['vote_average'];
            if (rating != null) {
              attributes['Note TMDb'] = '${rating.toString()}/10';
            }
            if (isTv) {
              final episodes = tmdbData['number_of_episodes'];
              final seasons = tmdbData['number_of_seasons'];
              if (episodes != null) attributes['Épisodes'] = episodes.toString();
              if (seasons != null) attributes['Saisons'] = seasons.toString();
            } else {
              final budget = tmdbData['budget'];
              final revenue = tmdbData['revenue'];
              if (budget != null && budget > 0) {
                attributes['Budget (TMDb)'] = '\$${_formatNumber(budget.toString())}';
              }
              if (revenue != null && revenue > 0) {
                attributes['Recettes (TMDb)'] = '\$${_formatNumber(revenue.toString())}';
              }
            }
          }
        }
      } else if (type == 'book') {
        final authors = getClaimEntityIds('P50').map((id) => resolvedLabels[id]).whereType<String>();
        if (authors.isNotEmpty) {
          attributes['Auteur'] = authors.join(', ');
        }

        final publishers = getClaimEntityIds('P123').map((id) => resolvedLabels[id]).whereType<String>();
        if (publishers.isNotEmpty) {
          attributes['Éditeur'] = publishers.join(', ');
        }

        final genres = getClaimEntityIds('P136', limit: 3).map((id) => resolvedLabels[id]).whereType<String>();
        if (genres.isNotEmpty) {
          attributes['Genre'] = genres.join(', ');
        }

        final pubTime = getClaimTimeValue('P577');
        if (pubTime != null) {
          attributes['Publication'] = _cleanWikidataDate(pubTime);
        }

        // Enrich with OpenLibrary API
        final isbn = getClaimStringValue('P212') ?? getClaimStringValue('P957');
        final olid = getClaimStringValue('P648');
        if (isbn != null || olid != null) {
          final olData = await _openLibraryService.fetchBookData(isbn: isbn, olid: olid);
          if (olData != null) {
            if (olData['number_of_pages'] != null) {
              attributes['Pages'] = olData['number_of_pages'].toString();
            }
            if (olData['publishers'] is List) {
              final pubNames = (olData['publishers'] as List)
                  .map((p) => p['name'] as String?)
                  .whereType<String>()
                  .toList();
              if (pubNames.isNotEmpty) {
                attributes['Éditeur (OpenLibrary)'] = pubNames.join(', ');
              }
            }
            if (olData['publish_date'] != null) {
              attributes['Publication (OL)'] = olData['publish_date'].toString();
            }
            if (olData['subjects'] is List) {
              final subjects = (olData['subjects'] as List)
                  .take(3)
                  .map((s) => s['name'] as String?)
                  .whereType<String>()
                  .toList();
              if (subjects.isNotEmpty) {
                attributes['Sujets'] = subjects.join(', ');
              }
            }
            // Use cover image if Wikidata doesn't have one
            if (imageUrl == null && olData['cover'] is Map) {
              final coverLarge = olData['cover']['large'];
              if (coverLarge is String && coverLarge.isNotEmpty) {
                imageUrl = coverLarge;
              }
            }
          }
        }
      } else if (type == 'animal') {
        final scientificName = getClaimStringValue('P225');
        if (scientificName != null) {
          attributes['Nom scientifique'] = scientificName;
        }

        final parentTaxon = getClaimEntityIds('P171').map((id) => resolvedLabels[id]).whereType<String>();
        if (parentTaxon.isNotEmpty) {
          attributes['Taxon parent'] = parentTaxon.join(', ');
        }

        final rank = getClaimEntityIds('P105').map((id) => resolvedLabels[id]).whereType<String>();
        if (rank.isNotEmpty) {
          attributes['Rang taxonomique'] = rank.join(', ');
        }

        final status = getClaimEntityIds('P141').map((id) => resolvedLabels[id]).whereType<String>();
        if (status.isNotEmpty) {
          attributes['Statut de conservation'] = status.join(', ');
        }
      }

      final result = UrofObject(
        id: id,
        title: label,
        type: type,
        description: desc,
        imageUrl: imageUrl,
        attributes: attributes,
        sourceUrl: 'https://www.wikidata.org/wiki/$id',
      );

      // Store in cache (using normalized text as key)
      _cacheService.put(normalizedText, result);

      return result;
    } on DioException catch (e) {
      print('WikidataService: Dio error for "$trimmedText": ${e.type} — ${e.message}');
      return null;
    } catch (e) {
      print('WikidataService: unexpected error for "$trimmedText": $e');
      return null;
    }
  }

  Future<Map<String, String>> _getEntityLabels(List<String> entityIds) async {
    if (entityIds.isEmpty) return {};
    final uniqueIds = entityIds.toSet().toList();
    final Map<String, String> result = {};

    for (var i = 0; i < uniqueIds.length; i += 50) {
      final chunk = uniqueIds.sublist(i, i + 50 > uniqueIds.length ? uniqueIds.length : i + 50);
      try {
        final res = await _dio.get(
          'https://www.wikidata.org/w/api.php',
          queryParameters: {
            'action': 'wbgetentities',
            'ids': chunk.join('|'),
            'props': 'labels',
            'languages': 'fr',
            'format': 'json',
          },
        );
        final entities = res.data['entities'];
        if (entities is Map) {
          entities.forEach((key, value) {
            final label = value['labels']?['fr']?['value'] ?? value['labels']?['en']?['value'];
            if (label != null) {
              result[key] = label;
            }
          });
        }
      } catch (e) {
        print('Error fetching batch labels: $e');
      }
    }
    return result;
  }

  String _normalizeSearchText(String text) {
    String normalized = text.toLowerCase();

    // Remove common French leading articles
    final articles = ['le ', 'la ', 'les ', 'un ', 'une ', 'des ', "l' "];
    for (final article in articles) {
      if (normalized.startsWith(article)) {
        normalized = normalized.substring(article.length);
        break; // only remove one article
      }
    }
    // Also handle "l'" without trailing space: "l'homme" -> "homme"
    if (normalized.startsWith("l'")) {
      normalized = normalized.substring(2);
    }

    // Normalize accents and diacritics
    normalized = normalized
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ÿ', 'y');

    // Replace apostrophes and hyphens with spaces (splits compound words)
    normalized = normalized.replaceAll("'", ' ').replaceAll('-', ' ');

    // Strip extra whitespace
    normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }

  String _cleanWikidataDate(String dateStr) {
    if (dateStr.startsWith('+')) {
      dateStr = dateStr.substring(1);
    }
    final tIdx = dateStr.indexOf('T');
    if (tIdx != -1) {
      dateStr = dateStr.substring(0, tIdx);
    }
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateStr;
  }

  String _formatNumber(String numStr) {
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
