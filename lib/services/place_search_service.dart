import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_result.dart';

abstract interface class PlaceSearchService {
  Future<List<PlaceResult>> search(String query);
  void dispose();
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _CachedPlaces {
  _CachedPlaces(this.results) : createdAt = DateTime.now();
  final List<PlaceResult> results;
  final DateTime createdAt;
}

class GeoapifyPlaceSearchService implements PlaceSearchService {
  GeoapifyPlaceSearchService({
    this.apiKey = 'f8a9d6d2d83248c285045a09d96c9c3e',
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String apiKey;
  final http.Client _client;
  final bool _ownsClient;
  final _cache = <String, _CachedPlaces>{};
  bool _disposed = false;

  @override
  Future<List<PlaceResult>> search(String query) async {
    if (_disposed) throw StateError('Search service is disposed.');
    final text = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length < 3) return const [];
    if (apiKey.trim().isEmpty) {
      throw const PlaceSearchException(
        'Wyszukiwanie wymaga klucza GEOAPIFY_API_KEY. Możesz wybrać punkt na mapie.',
      );
    }
    final key = text.toLowerCase();
    final cached = _cache.remove(key);
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(minutes: 5)) {
      _cache[key] = cached;
      return cached.results;
    }
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': text,
      'lang': 'pl',
      'filter': 'countrycode:pl',
      'limit': '8',
      'format': 'json',
      'apiKey': apiKey.trim(),
    });
    try {
      // Simple GET: no User-Agent or unnecessary CORS headers on Web.
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const PlaceSearchException(
          'Sprawdź klucz wyszukiwarki i dozwolone domeny w Geoapify.',
        );
      }
      if (response.statusCode == 429) {
        throw const PlaceSearchException(
          'Limit wyszukiwania został osiągnięty. Spróbuj ponownie później.',
        );
      }
      if (response.statusCode != 200) {
        throw const PlaceSearchException(
          'Wyszukiwarka jest chwilowo niedostępna.',
        );
      }
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
        throw const FormatException('Unexpected autocomplete response.');
      }
      final rows = decoded['results'] as List;
      final results = <PlaceResult>[];
      final seen = <String>{};
      for (final row in rows) {
        final place = PlaceResult.fromGeoapify(row);
        if (place != null && seen.add(place.id)) results.add(place);
      }
      final immutable = List<PlaceResult>.unmodifiable(results);
      if (!_disposed) {
        _cache[key] = _CachedPlaces(immutable);
        while (_cache.length > 40) {
          _cache.remove(_cache.keys.first);
        }
      }
      return immutable;
    } on TimeoutException {
      throw const PlaceSearchException(
        'Wyszukiwanie trwa zbyt długo. Spróbuj ponownie.',
      );
    } on http.ClientException {
      throw const PlaceSearchException(
        'Nie można połączyć się z wyszukiwarką. Sprawdź połączenie i ustawienia domeny API.',
      );
    } on FormatException {
      throw const PlaceSearchException(
        'Wyszukiwarka zwróciła nieprawidłową odpowiedź.',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    if (_ownsClient) _client.close();
  }
}
