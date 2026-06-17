import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'chat_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final databaseReference = FirebaseDatabase.instance.ref("ads");
  late Stream<DatabaseEvent> _adsStream;

  String _lastQuery = "";

  @override
  void initState() {
    super.initState();
    _adsStream = databaseReference.onValue;
  }

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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(52.2297, 21.0122),
                initialZoom: 13.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (tapPosition, point) {
                  _showAddAdForm(context, point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.activ_io',
                ),
                StreamBuilder(
                  stream: _adsStream,
                  builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                    List<Marker> mapMarkers = [];

                    if (snapshot.hasData &&
                        snapshot.data!.snapshot.value != null) {
                      final data =
                          snapshot.data!.snapshot.value
                              as Map<dynamic, dynamic>;

                      data.forEach((key, value) {
                        final ad = value as Map<dynamic, dynamic>;
                        if (ad['lat'] != null && ad['lng'] != null) {
                          mapMarkers.add(
                            Marker(
                              point: LatLng(ad['lat'], ad['lng']),
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  _showAdDetails(context, ad);
                                },
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.orange,
                                  size: 45,
                                ),
                              ),
                            ),
                          );
                        }
                      });
                    }
                    return MarkerLayer(markers: mapMarkers);
                  },
                ),
              ],
            ),
          ),

          Positioned(
            top: 40,
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
                _mapController.move(LatLng(option['lat'], option['lon']), 16.0);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    return Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(30),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: "np. Kraków, Rynek Główny...",
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.orange,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              controller.clear();
                              _lastQuery = "";
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    );
                  },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Wyszukaj miejsce, a następnie kliknij w mapę, by dodać pinezkę!',
              ),
            ),
          );
        },
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.touch_app),
        label: const Text(
          'DODAJ OGŁOSZENIE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showAddAdForm(BuildContext context, LatLng point) {
    String selectedCategory = "🏃 Bieganie";
    final TextEditingController descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Nowe wydarzenie",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  const Text(
                    "Kategoria:",
                    style: TextStyle(color: Colors.grey),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedCategory,
                    items:
                        [
                              "🏃 Bieganie",
                              "🚴 Rower",
                              "💪 Siłownia",
                              "⚽ Piłka nożna",
                              "🎾 Tenis",
                              "🧘 Joga",
                            ]
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedCategory = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText:
                          "Szczegóły (np. Szukam partnera na luźny trening, 18:00)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        final rawName =
                            user?.email?.split('@')[0] ?? "Nieznajomy";
                        final uniqueId = user?.uid.substring(0, 4) ?? "0000";
                        final userName = "$rawName#$uniqueId";

                        await databaseReference.push().set({
                          "category": selectedCategory,
                          "description": descriptionController.text,
                          "lat": point.latitude,
                          "lng": point.longitude,
                          "user": userName,
                          "timestamp": DateTime.now().millisecondsSinceEpoch,
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Dodano ogłoszenie!')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        "OPUBLIKUJ PINEZKĘ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdDetails(BuildContext context, Map<dynamic, dynamic> ad) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ad["category"] ?? 'Brak kategorii',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Dodał/a: ${ad["user"] ?? 'Nieznany'}",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(ad["description"] ?? '', style: const TextStyle(fontSize: 18)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  final myName =
                      "${user?.email?.split('@')[0] ?? "Nieznajomy"}-${user?.uid.substring(0, 4) ?? "0000"}";
                  final rawPeerName = ad["user"] ?? "Nieznany";
                  final peerName = rawPeerName.replaceAll('#', '-');
                  if (myName == peerName) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('To Twoje własne ogłoszenie! 😉'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(peerName: rawPeerName),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text(
                  "Napisz wiadomość",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
