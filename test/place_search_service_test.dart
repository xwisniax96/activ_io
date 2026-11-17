import 'dart:async';
import 'dart:convert';

import 'package:activ_io/models/place_result.dart';
import 'package:activ_io/services/place_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Polish labels and longitude/latitude are not swapped', () {
    final place = PlaceResult.fromGeoapify({
      'name': 'Sukiennice', 'street': 'Rynek Główny', 'housenumber': '1',
      'city': 'Kraków', 'lat': 50.0617, 'lon': 19.9373, 'result_type': 'amenity',
    });
    expect(place!.label, 'Sukiennice, Rynek Główny 1, Kraków');
    expect(place.point.latitude, 50.0617);
    expect(place.point.longitude, 19.9373);
    expect(place.zoom, 17);
  });

  test('City result has a regional subtitle and a wider zoom', () {
    final place = PlaceResult.fromGeoapify({
      'city': 'Łódź', 'state': 'łódzkie', 'address_line1': 'Łódź',
      'lat': '51.76', 'lon': '19.45', 'result_type': 'city',
    });
    expect(place!.label, 'Łódź, łódzkie');
    expect(place.zoom, 12);
  });

  test('Invalid coordinates and nameless results are discarded', () {
    for (final latitude in [null, 'NaN', 'bad', 91, double.infinity]) {
      expect(PlaceResult.fromGeoapify({
        'name': 'Bad', 'lat': latitude, 'lon': 19,
      }), isNull);
    }
    expect(PlaceResult.fromGeoapify({'lat': 50, 'lon': 19}), isNull);
  });

  test('Encodes Polish query, filters Poland, deduplicates and caches', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'api.geoapify.com');
      expect(request.url.queryParameters['text'], 'Łódź Piotrkowska & park');
      expect(request.url.queryParameters['lang'], 'pl');
      expect(request.url.queryParameters['filter'], 'countrycode:pl');
      final row = {
        'place_id': 'one', 'street': 'Piotrkowska', 'city': 'Łódź',
        'lat': 51.76, 'lon': 19.45,
      };
      return http.Response.bytes(utf8.encode(jsonEncode({
        'results': [row, row, {'name': 'Invalid', 'lat': 500, 'lon': 19}],
      })), 200);
    });
    final service = GeoapifyPlaceSearchService(apiKey: 'test', client: client);
    addTearDown(service.dispose);
    addTearDown(client.close);
    final first = await service.search(' Łódź   Piotrkowska & park ');
    final second = await service.search('łódź piotrkowska & park');
    expect(first, hasLength(1));
    expect(second, same(first));
    expect(calls, 1);
  });

  test('Missing key and short queries do not send network requests', () async {
    final client = MockClient((request) async => fail('Unexpected network request'));
    final service = GeoapifyPlaceSearchService(apiKey: '', client: client);
    addTearDown(service.dispose);
    addTearDown(client.close);
    expect(await service.search('Kr'), isEmpty);
    await expectLater(service.search('Kraków'), throwsA(isA<PlaceSearchException>()));
  });

  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status is an error, not an empty results list', () async {
      final client = MockClient((request) async => http.Response('{}', status));
      final service = GeoapifyPlaceSearchService(apiKey: 'test', client: client);
      addTearDown(service.dispose);
      addTearDown(client.close);
      await expectLater(service.search('Kraków'), throwsA(isA<PlaceSearchException>()));
    });
  }

  test('Malformed payload and timeout become readable search errors', () async {
    for (final timedOut in [false, true]) {
      final client = MockClient((request) async {
        if (timedOut) throw TimeoutException('simulated');
        return http.Response('{broken', 200);
      });
      final service = GeoapifyPlaceSearchService(apiKey: 'test', client: client);
      await expectLater(service.search('Kraków'), throwsA(isA<PlaceSearchException>()));
      service.dispose();
      client.close();
    }
  });
}
