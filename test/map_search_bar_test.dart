import 'dart:async';

import 'package:activ_io/models/place_result.dart';
import 'package:activ_io/services/place_search_service.dart';
import 'package:activ_io/widgets/map_search_bar.dart';
// ignore: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class PendingSearch {
  PendingSearch(this.query);
  final String query;
  final completion = Completer<List<PlaceResult>>();
}

class FakeSearch implements PlaceSearchService {
  final requests = <PendingSearch>[];
  @override
  Future<List<PlaceResult>> search(String query) {
    final request = PendingSearch(query);
    requests.add(request);
    return request.completion.future;
  }
  @override
  void dispose() {}
}

PlaceResult place(String title) => PlaceResult(
  id: title, title: title, subtitle: 'Polska', point: const LatLng(50, 19),
);

Future<void> mountSearch(WidgetTester tester, FakeSearch service, {
  ValueChanged<PlaceResult>? onSelected,
  VoidCallback? onCleared,
}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: SizedBox(
      width: 320, height: 350,
      child: MapSearchBar(service: service,
        onSelected: onSelected ?? (_) {}, onCleared: onCleared),
    )),
  )));
}

Future<void> typeAndStart(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('Fast typing sends only the final query', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await tester.enterText(find.byType(TextField), 'Kra');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'Kraków');
    await tester.pump(const Duration(milliseconds: 349));
    expect(service.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.requests.single.query, 'Kraków');
    service.requests.single.completion.complete([place('Kraków')]);
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('Old response cannot appear during a newer debounce', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await typeAndStart(tester, 'Krak');
    await tester.enterText(find.byType(TextField), 'Warszawa');
    service.requests.first.completion.complete([place('Old Kraków')]);
    await tester.pump();
    expect(find.text('Old Kraków'), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    service.requests.last.completion.complete([place('Nowa Warszawa')]);
    await tester.pump();
    expect(find.text('Nowa Warszawa'), findsOneWidget);
  });

  testWidgets('Out-of-order responses keep the latest results', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await typeAndStart(tester, 'Kraków');
    await typeAndStart(tester, 'Warszawa');
    service.requests.last.completion.complete([place('Nowa Warszawa')]);
    await tester.pump();
    service.requests.first.completion.complete([place('Stary Kraków')]);
    await tester.pump();
    expect(find.text('Nowa Warszawa'), findsOneWidget);
    expect(find.text('Stary Kraków'), findsNothing);
  });

  testWidgets('Clear invalidates pending responses and clears selection', (tester) async {
    final service = FakeSearch();
    var cleared = false;
    await mountSearch(tester, service, onCleared: () => cleared = true);
    await typeAndStart(tester, 'Kraków');
    await tester.tap(find.byTooltip('Wyczyść wyszukiwanie'));
    service.requests.single.completion.complete([place('Late Kraków')]);
    await tester.pump();
    expect(cleared, isTrue);
    expect(find.text('Late Kraków'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('Deleting below minimum length rejects an old result', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await typeAndStart(tester, 'Kraków');
    await tester.enterText(find.byType(TextField), 'Kr');
    service.requests.single.completion.complete([place('Late Kraków')]);
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.requests, hasLength(1));
    expect(find.text('Late Kraków'), findsNothing);
    expect(find.text('Wpisz co najmniej 3 znaki.'), findsOneWidget);
  });

  testWidgets('Click selects coordinates once and closes the list', (tester) async {
    final service = FakeSearch();
    final selections = <PlaceResult>[];
    await mountSearch(tester, service, onSelected: selections.add);
    await typeAndStart(tester, 'Kraków');
    final result = place('Rynek Główny');
    service.requests.single.completion.complete([result]);
    await tester.pump();
    await tester.tap(find.byType(ListTile));
    await tester.pump(const Duration(milliseconds: 400));
    expect(selections.single, same(result));
    expect(find.byType(ListTile), findsNothing);
    expect(service.requests, hasLength(1));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, result.label);
  });

  testWidgets('Arrow keys and Search select the highlighted result', (tester) async {
    final service = FakeSearch();
    PlaceResult? selected;
    await mountSearch(tester, service, onSelected: (value) => selected = value);
    await typeAndStart(tester, 'Kraków');
    service.requests.single.completion.complete([place('First'), place('Second')]);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(selected!.title, 'Second');
  });

  testWidgets('Escape prevents a pending request reopening suggestions', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await typeAndStart(tester, 'Kraków');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    service.requests.single.completion.complete([place('Late result')]);
    await tester.pump();
    expect(find.text('Late result'), findsNothing);
  });

  testWidgets('Error and retry are visible; a valid empty response says no results', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await typeAndStart(tester, 'Kraków');
    service.requests.single.completion.completeError(const PlaceSearchException('Limit API'));
    await tester.pump();
    expect(find.text('Limit API'), findsOneWidget);
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pump(const Duration(milliseconds: 350));
    service.requests.last.completion.complete([]);
    await tester.pump();
    expect(find.text('Brak wyników. Spróbuj dodać miasto lub zmienić nazwę.'), findsOneWidget);
  });

  testWidgets('Disposal cancels timers and safely ignores in-flight responses', (tester) async {
    final service = FakeSearch();
    await mountSearch(tester, service);
    await typeAndStart(tester, 'Kraków');
    await tester.pumpWidget(const SizedBox());
    service.requests.single.completion.complete([place('Late result')]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await mountSearch(tester, service);
    await tester.enterText(find.byType(TextField), 'Gdańsk');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(service.requests, hasLength(1));
  });
}
