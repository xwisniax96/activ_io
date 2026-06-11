import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math'; // Dodane, żeby trochę "rozsypać" testowe pinezki

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  // Wskazujemy na nasz folder z ogłoszeniami w chmurze
  final databaseReference = FirebaseDatabase.instance.ref("ads");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // StreamBuilder to nasz "nasłuchiwacz" - odświeża mapę, gdy tylko coś zmieni się w bazie
      body: StreamBuilder(
        stream: databaseReference.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          // 1. Zbieramy wszystkie pinezki do listy
          List<Marker> mapMarkers = [];

          // 2. Jeśli mamy dane z serwera, tłumaczymy je na pinezki
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            // Firebase zwraca dane jako mapę: { id_ogloszenia: { dane... }, id_ogloszenia2: { dane... } }
            final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

            data.forEach((key, value) {
              final ad = value as Map<dynamic, dynamic>;

              // Zabezpieczenie: upewniamy się, że ogłoszenie ma koordynaty
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

          // 3. Zwracamy mapę z nałożonymi pinezkami
          return FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(52.2297, 21.0122),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.activ_io',
              ),
              MarkerLayer(markers: mapMarkers),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Używam odrobiny matematyki, żeby lekko rozrzucić testowe pinezki wokół centrum.
          // Inaczej nakładałyby się na siebie idealnie w jednym punkcie!
          final randomLat = 52.2297 + (Random().nextDouble() - 0.5) * 0.05;
          final randomLng = 21.0122 + (Random().nextDouble() - 0.5) * 0.05;

          await databaseReference.push().set({
            "category": "🏃 Bieganie",
            "description": "Cześć! Ktoś chętny na wieczorny bieg?",
            "lat": randomLat,
            "lng": randomLng,
            "user": "TwójTestowyUser",
            "timestamp": DateTime.now().millisecondsSinceEpoch,
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nowa pinezka dodana!')),
            );
          }
        },
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.send),
        label: const Text(
          'DODAJ PINEZKĘ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Funkcja rysująca wysuwane okienko po kliknięciu w pinezkę
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
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tu otworzy się czat (Faza 4)!'),
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
