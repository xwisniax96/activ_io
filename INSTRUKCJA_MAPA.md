# ACTIV.io — wyszukiwanie i wybór miejsca

## Wdrożenie

Archiwum zawiera projekt z poprawkami. Skopiuj zmienione pliki do swojej kopii projektu,
zachowując własny `lib/firebase_options.dart` i pozostałą lokalną konfigurację Firebase.
Pliku `firebase_options.dart` nie było w załączonym archiwum, mimo że `main.dart` go importuje.
Jeżeli nie masz go także lokalnie, wygeneruj go przez FlutterFire CLI dla swojego istniejącego
projektu Firebase (`flutterfire configure`). Nie zastępuj go przykładowymi poświadczeniami.

1. Utwórz klucz API w https://myprojects.geoapify.com/ dla Address Autocomplete.
2. W ustawieniach klucza zezwól na lokalny adres aplikacji (np. localhost:8080) i docelową domenę
   zgodnie z formatem ustawień origin/referrer dostawcy. Używaj klucza przeznaczonego dla Web.
3. Uruchom w katalogu projektu:

```sh
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=GEOAPIFY_API_KEY=TWOJ_KLUCZ
```

Dla wersji publikowanej:

```sh
flutter build web --dart-define=GEOAPIFY_API_KEY=TWOJ_KLUCZ
```

Zmiana `--dart-define` wymaga ponownego uruchomienia/przebudowania, nie samego hot reload.
Klucz przekazany do Flutter Web jest widoczny w aplikacji i zapytaniach przeglądarki;
`--dart-define` nie służy do przechowywania sekretów. Ogranicz klucz do swoich domen i limitów.
Nie trzeba wyłączać zabezpieczeń Chrome ani dodawać rozszerzeń obchodzących CORS.
Bez klucza wyszukiwarka pokaże komunikat konfiguracyjny; ręczny wybór punktu nadal działa.
Nie dodano nowych zależności do pubspec.yaml ani nie podniesiono wersji paczek.

## Działanie

- Wpisz co najmniej 3 znaki. Jeden Timer uruchamia zapytanie po 350 ms bez zmiany tekstu.
- Każda edycja natychmiast unieważnia wcześniejsze odpowiedzi, także podczas oczekiwania na timer.
- Stare odpowiedzi i błędy nie zastąpią wyników nowszego zapytania. Czyszczenie, Escape,
  utrata fokusu i dispose także unieważniają zapytania.
- Anulowanie jest logiczne; wysłane już żądanie może dotrzeć do dostawcy i zużyć limit API.
- Geoapify Autocomplete otrzymuje `lang=pl`, `filter=countrycode:pl`, limit 8 i format JSON.
  Dopasowanie fragmentów adresów oraz kolejność wyników należą do dostawcy. Nie jest to lokalna
  baza wszystkich miejsc ani gwarancja rozpoznania każdej literówki. Zasięg POI zależy od danych API.
- Cache przechowuje maksymalnie 40 zapytań przez 5 minut. Żądanie ma timeout 8 sekund.
- Osobno pokazywane są brak wyników, brak klucza, błędy HTTP/sieci i przekroczenie limitu.
- Etykiety pokazują nazwę/ulicę, numer i miejscowość. Model `PlaceResult` zastępuje
  zagnieżdżone typy generyczne oparte na Map w nowej wyszukiwarce.
- Kliknięcie wyniku wybiera współrzędne, zamyka listę i wywołuje `mapController.move` w MapScreen.
  Przybliżenie jest szersze dla miasta, dokładniejsze dla ulicy i punktu.
- Niebieska pinezka oznacza wybór; pomarańczowe pinezki pozostają ogłoszeniami.
- Kliknięcie mapy zmienia wybór. Przycisk „DODAJ OGŁOSZENIE TUTAJ” otwiera istniejący formularz
  ze współrzędnymi tego punktu. Samo wyszukanie/kliknięcie nie zapisuje nic do Firebase.
- X w wyszukiwarce czyści tekst i zaznaczenie. X na karcie usuwa samo zaznaczenie.
- Strzałki wybierają podpowiedź, Enter/Search zatwierdza, Escape zamyka listę.
- Późna odpowiedź GPS nie nadpisuje wyboru ani wcześniejszego przesunięcia mapy.
- Kontroler mapy jest zwalniany, a `move` czeka na gotowość mapy.

API widgetu zmieniło się: zamiast `mapController` przyjmuje `onSelected` i opcjonalne `onCleared`.
Widget jest umieszczany w ograniczonym wysokością kontenerze; `Positioned` należy do MapScreen.
Pozostałe ekrany nie mają przebudowanej logiki biznesowej — otrzymały tylko wyciszenie importu.

## Ostrzeżenia Material

Importy `package:flutter/material.dart` zostały zachowane. Nad każdą taką linią dodano:

```dart
// ignore: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
```

To wyciszenie dotyczy wyłącznie wskazanej linii. `analysis_options.yaml` zachowuje diagnostykę
pozostałych przestarzałych API na poziomie warning. Globalne `deprecated_member_use: ignore`
ukryłoby także przyszłe użycia `withOpacity`, więc nie zostało zastosowane.
W dostarczonym kodzie nie było już wywołań `withOpacity`; istniejące `withAlpha` zachowano.
Po podmianie uruchom w VS Code „Dart: Restart Analysis Server”, jeśli stare ostrzeżenia pozostaną.

Wyciszenie jest rozwiązaniem przejściowym i nie naprawia błędów kompilacji ani ewentualnego
usunięcia biblioteki w przyszłym SDK. Problemy z podstawowymi typami Dart należy diagnozować
osobno na podstawie pierwszego błędu analizatora. Nie dodano globalnego wyłączania diagnostyki.
Dokumentacja Fluttera rozróżnia udostępnienie osobnych pakietów od 3.47 i formalną deprecjację
bibliotek SDK w 3.50; dokładny komunikat zależy też od używanego kanału SDK.

## Pliki

- `lib/models/place_result.dart` — nowy model i walidacja odpowiedzi.
- `lib/services/place_search_service.dart` — Geoapify, cache, timeout, czytelne błędy.
- `lib/widgets/map_search_bar.dart` — TextField, debounce, lista, obsługa klawiatury.
- `lib/screens/map_screen.dart` — integracja, pinezka wyboru, GPS, przycisk potwierdzenia.
- `analysis_options.yaml` oraz importy Material w `lib/` — wyciszenie ograniczone do importów.
- `test/place_search_service_test.dart`, `test/map_search_bar_test.dart` — testy regresji.

## Weryfikacja

W środowisku przygotowania sprawdzono parsowanie wszystkich plików Dart i obu plików YAML,
integralność ZIP oraz zachowanie niezmienionych plików z oryginalnego archiwum.
Sprawdzenie parserem nie zastępuje analizatora typów Dart.
Nie było SDK Flutter/Dart, konfiguracji Firebase ani klucza Geoapify użytkownika, dlatego
NIE wykonano `flutter analyze`, `flutter test`, kompilacji ani testu na żywym API w Chrome.
Testy z MockClient/FakeSearch nie kontaktują się z Geoapify ani Firebase.

Wykonaj lokalnie:

```sh
dart format lib/models/place_result.dart lib/services/place_search_service.dart lib/widgets/map_search_bar.dart lib/screens/map_screen.dart test
flutter analyze
flutter test
```

Testy obejmują debounce, kolejność odpowiedzi, stare odpowiedzi przed kolejnym timerem,
czyszczenie, zbyt krótki tekst, wybór kliknięciem/klawiaturą, Escape, retry i dispose,
a także etykiety, współrzędne, kodowanie znaków, deduplikację, cache i błędy API.

W Chrome sprawdź także:

1. `kraków rynek główny`, `krakow rynek gl`, `Łódź Piotrkowska`, `Warszawa Kopernik`.
   Oceń trafność wyników na swoim kluczu; nie była potwierdzona na żywym API.
2. Szybko zmień Kraków na Warszawę, również z włączonym throttlingiem sieci.
3. Wybierz wynik: mapa ma przesunąć się do niego i pokazać niebieską pinezkę.
4. Kliknij inne miejsce mapy: pinezka i współrzędne karty muszą się zmienić.
5. Otwórz formularz przyciskiem; anuluj go i sprawdź, że nic nie zostało zapisane.
6. Kliknij pomarańczową pinezkę: powinny otworzyć się szczegóły istniejącego ogłoszenia.
7. Odmów dostępu do GPS, sprawdź brak klucza, błąd sieci i małą wysokość okna/klawiaturę.

## Dokumentacja decyzji

- Flutter: https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
- Wyciszenia analizatora: https://dart.dev/tools/analysis
- API i klucze: https://apidocs.geoapify.com/docs/geocoding/address-autocomplete/
- Publiczny Nominatim zabrania autocomplete:
  https://operations.osmfoundation.org/policies/nominatim/

Nie podmieniono Photona na publiczny Nominatim, nie użyto publicznych proxy CORS i nie
zmieniono importów na material_ui. Nie ma automatycznego przełączania na inne publiczne API.
