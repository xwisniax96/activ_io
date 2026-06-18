import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'chat_screen.dart';
import 'package:activ_io/widgets/map_search_bar.dart';
import 'package:activ_io/services/database_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late Stream<DatabaseEvent> _adsStream;
  StreamSubscription? _banSubscription;

  //su admin
  final String adminEmail = "xwisniax96@gmail.com";

  @override
  void initState() {
    super.initState();
    _adsStream = DatabaseService.instance.adsRef.onValue;
    _getUserLocation();
    _listenForBanHammer();
  }

  void _listenForBanHammer() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return; // <-- DODANE KLAMRY
    }

    _banSubscription = DatabaseService.instance.bannedRef
        .child(user.uid)
        .onValue
        .listen((event) async {
          if (event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            final String reason =
                data['reason'] ?? "Złamanie regulaminu aplikacji";

            await FirebaseAuth.instance.signOut();

            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.red.shade50,
                  title: const Text(
                    '🛑 KONTO ZABLOKOWANE',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    'Twoje konto zostało trwale zbanowane przez Administratora.\n\nPowód: $reason',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            }
          }
        });
  }

  @override
  void dispose() {
    _banSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // <-- DODANE KLAMRY
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
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
                initialCenter: const LatLng(50.0614, 19.9366),
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
                  keepBuffer: 4,
                  panBuffer: 2,
                  tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 200),
                  ),
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
                      final int currentTimeMs =
                          DateTime.now().millisecondsSinceEpoch;

                      data.forEach((key, value) {
                        final ad = value as Map<dynamic, dynamic>;
                        final int endTimeMs = ad['endTime'] ?? 0;

                        if (ad['lat'] != null &&
                            ad['lng'] != null &&
                            currentTimeMs <= endTimeMs) {
                          mapMarkers.add(
                            Marker(
                              point: LatLng(ad['lat'], ad['lng']),
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  _showAdDetails(
                                    context,
                                    key,
                                    ad,
                                  ); // Przekazujemy klucz do usuwania/bana
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
          MapSearchBar(mapController: _mapController),
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
    final TextEditingController customCategoryController =
        TextEditingController();

    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now().add(const Duration(days: 1));

    String formatDate(DateTime d) {
      return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> pickDateTime(bool isStart) async {
              final date = await showDatePicker(
                context: context,
                initialDate: isStart ? startTime : endTime,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );

              if (date == null) {
                return; // <-- DODANE KLAMRY
              }

              if (!context.mounted) {
                return; // <-- DODANE KLAMRY
              }

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  isStart ? startTime : endTime,
                ),
              );

              if (time == null) {
                return; // <-- DODANE KLAMRY
              }

              setState(() {
                final newDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                if (isStart) {
                  startTime = newDateTime;
                  if (endTime.isBefore(startTime)) {
                    endTime = startTime.add(
                      const Duration(hours: 1),
                    ); // <-- DODANE KLAMRY
                  }
                } else {
                  if (newDateTime.isBefore(startTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Czas końca nie może być przed czasem startu!',
                        ),
                      ),
                    );
                  } else {
                    endTime = newDateTime;
                  }
                }
              });
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  color: Colors.white.withAlpha(220),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Nowe wydarzenie",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Kategoria:",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCategory,
                          dropdownColor: Colors.white.withAlpha(240),
                          items:
                              [
                                    "🏃 Bieganie",
                                    "🚴 Rower",
                                    "💪 Siłownia",
                                    "⚽ Piłka nożna",
                                    "🎾 Tenis",
                                    "🧘 Joga",
                                    "✏️ Inne (wpisz własną)",
                                  ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) =>
                              setState(() => selectedCategory = val!),
                        ),
                        if (selectedCategory == "✏️ Inne (wpisz własną)") ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: customCategoryController,
                            decoration: const InputDecoration(
                              labelText: "Wpisz własną kategorię...",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        const Text(
                          "Kiedy? (max 30 dni)",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => pickDateTime(true),
                                icon: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.green,
                                ),
                                label: Text(
                                  formatDate(startTime),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => pickDateTime(false),
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  color: Colors.red,
                                ),
                                label: Text(
                                  formatDate(endTime),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: descriptionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText:
                                "Szczegóły (np. Szukam kogoś na rower, 18:00)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;

                              String userName;
                              if (user?.email == adminEmail) {
                                userName =
                                    user?.displayName ??
                                    "support.ACTIV.io"; // Nazwa Admina
                              } else {
                                final rawName =
                                    user?.email?.split('@')[0] ?? "Nieznajomy";
                                final uniqueId =
                                    user?.uid.substring(0, 4) ?? "0000";
                                userName =
                                    user?.displayName ?? "$rawName#$uniqueId";
                              }

                              String finalCategory = selectedCategory;
                              if (selectedCategory ==
                                  "✏️ Inne (wpisz własną)") {
                                finalCategory =
                                    customCategoryController.text.isNotEmpty
                                    ? "🔹 ${customCategoryController.text}"
                                    : "🔹 Różne";
                              }

                              await DatabaseService.instance.addAd({
                                "category": finalCategory,
                                "description": descriptionController.text,
                                "lat": point.latitude,
                                "lng": point.longitude,
                                "user": userName,
                                "ownerUid": user?.uid, // Zabezpieczenie ID
                                "startTime": startTime.millisecondsSinceEpoch,
                                "endTime": endTime.millisecondsSinceEpoch,
                              });

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Dodano ogłoszenie! Pojawi się na mapie.',
                                    ),
                                  ),
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAdDetails(
    BuildContext context,
    String adKey,
    Map<dynamic, dynamic> ad,
  ) {
    final int startMs =
        ad['startTime'] ?? DateTime.now().millisecondsSinceEpoch;
    final int endMs = ad['endTime'] ?? DateTime.now().millisecondsSinceEpoch;
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startMs);
    final DateTime endDate = DateTime.fromMillisecondsSinceEpoch(endMs);

    String formattedTime =
        "Od: ${startDate.day.toString().padLeft(2, '0')}.${startDate.month.toString().padLeft(2, '0')} ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}\n"
        "Do: ${endDate.day.toString().padLeft(2, '0')}.${endDate.month.toString().padLeft(2, '0')} ${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}";

    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == adminEmail;

    final adOwnerUid = ad["ownerUid"];
    bool isMyAd = false;

    if (adOwnerUid != null) {
      isMyAd = (user?.uid == adOwnerUid);
    } else {
      final myOldName =
          "${user?.email?.split('@')[0] ?? "Nieznajomy"}-${user?.uid.substring(0, 4) ?? "0000"}";
      final peerName = (ad["user"] ?? "Nieznany").toString().replaceAll(
        '#',
        '-',
      );
      isMyAd = (myOldName == peerName);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            color: Colors.white.withAlpha(220),
            padding: const EdgeInsets.all(24),
            height: isAdmin && !isMyAd
                ? 380
                : 320, // Więcej miejsca na przycisk BANA
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
                const SizedBox(height: 5),
                Text(
                  "Dodał/a: ${ad["user"] ?? 'Nieznany'}",
                  style: TextStyle(
                    color: isAdmin && !isMyAd ? Colors.red : Colors.grey,
                    fontSize: 14,
                    fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      ad["description"] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                // PANEL ADMINA: Młot Banicji (Pojawia się tylko dla Admina na cudzych ogłoszeniach)
                if (isAdmin && !isMyAd && adOwnerUid != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Otwieramy okienko do wpisania powodu bana
                        final TextEditingController banReasonController =
                            TextEditingController();
                        showDialog(
                          context: context,
                          builder: (banCtx) => AlertDialog(
                            title: const Text(
                              '🛑 Zbanuj Użytkownika',
                              style: TextStyle(color: Colors.red),
                            ),
                            content: TextField(
                              controller: banReasonController,
                              decoration: const InputDecoration(
                                hintText: "Podaj powód (np. Spam na mapie)",
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(banCtx),
                                child: const Text('Anuluj'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final reason =
                                      banReasonController.text.isEmpty
                                      ? "Spam / Łamanie regulaminu"
                                      : banReasonController.text;
                                  await DatabaseService.instance.banUser(
                                    adOwnerUid,
                                    reason,
                                  );
                                  await DatabaseService.instance.adsRef
                                      .child(adKey)
                                      .remove(); // Kasujemy jego pinezkę
                                  if (context.mounted) {
                                    Navigator.pop(
                                      banCtx,
                                    ); // Zamyka okienko bana
                                    Navigator.pop(ctx); // Zamyka dolny panel
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '🔨 Użytkownik zbanowany, a pinezka usunięta!',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('ZBANUJ'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.gavel),
                      label: const Text(
                        "ZBANUJ UŻYTKOWNIKA",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    // Przycisk Usuwania (Właściciel LUB Admin)
                    if (isMyAd || isAdmin)
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await DatabaseService.instance.adsRef
                                .child(adKey)
                                .remove();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🗑️ Usunięto pinezkę.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Icon(Icons.delete),
                        ),
                      ),
                    if (isMyAd || isAdmin) const SizedBox(width: 10),

                    // Przycisk Czatu
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isMyAd) {
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
                              builder: (context) => ChatScreen(
                                peerName: (ad["user"] ?? "Nieznany")
                                    .toString()
                                    .replaceAll('#', '-'),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text(
                          "Napisz",
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
