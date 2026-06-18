import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui'; // Potrzebne do rozmycia (BackdropFilter)

class MapSearchBar extends StatefulWidget {
  final MapController mapController;

  const MapSearchBar({super.key, required this.mapController});

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  String _lastQuery = "";

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('https://photon.komoot.io/api/?q=$query&limit=5');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final List features = data['features'] ?? [];

        return features.map((e) {
          final props = e['properties'];
          final coords = e['geometry']['coordinates'];

          String name = props['name'] ?? props['street'] ?? '';
          String city = props['city'] ?? props['state'] ?? '';
          String fullName = name.isNotEmpty
              ? (city.isNotEmpty ? "$name, $city" : name)
              : city;

          return {
            'display_name': fullName.isEmpty ? "Nieznane miejsce" : fullName,
            'lat': coords[1],
            'lon': coords[0],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Błąd wyszukiwarki Photon: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 15,
      left: 20,
      right: 20,
      child: Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (TextEditingValue textEditingValue) async {
          final query = textEditingValue.text;

          if (query.length < 4) {
            return const Iterable<Map<String, dynamic>>.empty();
          }
          await Future.delayed(const Duration(milliseconds: 600));
          if (query != _lastQuery) {
            _lastQuery = query;
            return await _searchPlaces(query);
          }
          return const Iterable<Map<String, dynamic>>.empty();
        },
        displayStringForOption: (option) {
          final parts = option['display_name'].split(',');
          if (parts.length >= 2) {
            return "${parts[0].trim()}, ${parts[1].trim()}";
          }
          return option['display_name'];
        },
        onSelected: (option) {
          FocusScope.of(context).unfocus();
          widget.mapController.move(LatLng(option['lat'], option['lon']), 16.0);
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          // Szklany efekt: ClipRRect obcina krawędzie, BackdropFilter rozmywa tło
          return ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(153), // Półprzezroczyste tło
                  borderRadius: BorderRadius.circular(30),
                  // Delikatna, biała ramka symulująca odbicie światła na krawędzi szkła
                  border: Border.all(color: Colors.white.withAlpha(204), width: 1.5),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: "np. Kraków, Rynek Główny...",
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        controller.clear();
                        _lastQuery = "";
                      },
                    ),
                    filled: false, // WAŻNE: Musi być false, żeby przepuścić rozmycie
                    border: InputBorder.none, // Usuwamy domyślne, sztywne ramki
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}