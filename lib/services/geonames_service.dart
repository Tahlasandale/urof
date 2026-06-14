import 'package:dio/dio.dart';

/// GeoNames service to enrich "city" type records with geographical data.
/// Uses the GeoNames API (http://api.geonames.org).
class GeoNamesService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
  ));

  /// GeoNames username.
  /// Priority: custom constructor parameter > environment variable GEONAMES_USERNAME > 'demo'.
  static const String _envUsername = String.fromEnvironment(
    'GEONAMES_USERNAME',
    defaultValue: 'demo',
  );

  final String? _customUsername;

  GeoNamesService({String? username}) : _customUsername = username;

  String get _username {
    if (_customUsername != null && _customUsername.isNotEmpty) {
      return _customUsername;
    }
    return _envUsername.isNotEmpty ? _envUsername : 'demo';
  }

  /// Searches GeoNames using the searchJSON endpoint.
  ///
  /// Utilizes the [query] to find locations, returning up to 1 row.
  /// Uses style=FULL to retrieve maximum details like timezone and elevation.
  Future<Map<String, dynamic>?> searchByName(String query) async {
    try {
      final response = await _dio.get(
        'http://api.geonames.org/searchJSON',
        queryParameters: {
          'q': query,
          'maxRows': 1,
          'username': _username,
          'style': 'FULL',
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
    } catch (e) {
      print('GeoNamesService error: $e');
    }
    return null;
  }

  /// Fetches rich details for a city by name.
  ///
  /// Returns a Map containing: pays, population, latitude, longitude, altitude, fuseau horaire, code postal.
  /// Returns null in case of failure or if no results are found.
  Future<Map<String, dynamic>?> fetchCityDetails(String cityName) async {
    try {
      final searchResult = await searchByName(cityName);
      if (searchResult == null) return null;

      final geonames = searchResult['geonames'];
      if (geonames is! List || geonames.isEmpty) {
        return null;
      }

      final city = geonames[0] as Map<String, dynamic>;

      // Extract coordinates
      final lat = city['lat'];
      final lng = city['lng'];
      final countryCode = city['countryCode']?.toString();

      // Extract postal code from main response if available,
      // otherwise fallback to a dedicated postal code search.
      String? postalCode = city['postalCode']?.toString() ?? city['postalcode']?.toString();
      if (postalCode == null && countryCode != null) {
        postalCode = await _fetchPostalCode(cityName, countryCode);
      }

      // Extract timezone
      final timezoneObj = city['timezone'];
      String? timezone;
      if (timezoneObj is Map<String, dynamic>) {
        timezone = timezoneObj['timezoneId']?.toString() ?? timezoneObj['timeZoneId']?.toString();
      }

      // Extract altitude/elevation
      final altitudeVal = city['elevation'] ?? city['srtm3'];
      int? altitude;
      if (altitudeVal != null) {
        altitude = int.tryParse(altitudeVal.toString());
      }

      return {
        'pays': city['countryName'] ?? city['countryCode'],
        'population': city['population'] != null ? int.tryParse(city['population'].toString()) ?? city['population'] : null,
        'latitude': lat != null ? double.tryParse(lat.toString()) : null,
        'longitude': lng != null ? double.tryParse(lng.toString()) : null,
        'altitude': altitude,
        'fuseau horaire': timezone,
        'code postal': postalCode,
      };
    } catch (e) {
      print('GeoNamesService error: $e');
    }
    return null;
  }

  /// Fallback utility to search for a postal code using postalCodeSearchJSON.
  Future<String?> _fetchPostalCode(String cityName, String countryCode) async {
    try {
      final response = await _dio.get(
        'http://api.geonames.org/postalCodeSearchJSON',
        queryParameters: {
          'placename': cityName,
          'country': countryCode,
          'maxRows': 1,
          'username': _username,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final postalCodes = data['postalCodes'];
        if (postalCodes is List && postalCodes.isNotEmpty) {
          final first = postalCodes[0];
          if (first is Map<String, dynamic>) {
            return first['postalCode']?.toString();
          }
        }
      }
    } catch (e) {
      print('GeoNamesService error: $e');
    }
    return null;
  }
}
