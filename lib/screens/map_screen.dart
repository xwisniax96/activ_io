import 'dart:async';
import 'dart:ui';

// Keep SDK Material types until the application migrates as a whole.
// ignore: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place_result.dart';
import '../widgets/map_search_bar.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late Stream<DatabaseEvent> _adsStream;
  StreamSubscription<DatabaseEvent>? _banSubscription;
  bool _mapReady = false;
  bool _userInteracted = false;
  bool _adFormOpen = false;
  LatLng? _gpsCenter;
  LatLng? _selectedPoint;
  String? _selectedLabel;

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
    if (user == null) return;
    _banSubscription = DatabaseService.instance.bannedRef
        .child(user.uid).onValue.listen((event) async {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final String reason = data['reason'] ?? 'Złamanie regulaminu aplikacji';
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.red.shade50,
            title: const Text('🛑 KONTO ZABLOKOWANE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text(
              'Twoje konto zostało trwale zbanowane przez Administratora.\n\nPowód: $reason',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _banSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled() || !mounted) return;
      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted || permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 12)),
      );
      if (!mounted) return;
      _gpsCenter = LatLng(position.latitude, position.longitude);
      // A late GPS response must never undo a search or a user's map movement.
      if (_mapReady && !_userInteracted) {
        _mapController.move(_gpsCenter!, 14);
      }
    } catch (_) {
      // Location is optional; map selection and search remain available.
    }
  }

  void _selectPlace(PlaceResult place) {
    _selectPoint(place.point, label: place.label);
    if (_mapReady) _mapController.move(place.point, place.zoom);
  }

  void _selectPoint(LatLng point, {String? label}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _userInteracted = true;
      _selectedPoint = point;
      _selectedLabel = label ?? 'Wybrany punkt na mapie';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPoint = null;
      _selectedLabel = null;
    });
  }

  void _addAtSelectedPoint() {
    final point = _selectedPoint;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Wyszukaj miejsce lub kliknij mapę, aby wybrać punkt.'),
      ));
      return;
    }
    _showAddAdForm(context, point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(50.0614, 19.9366),
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    // Wait until attachment/layout has completed before moving.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_userInteracted && _gpsCenter != null) {
                        _mapController.move(_gpsCenter!, 14);
                      }
                    });
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) _userInteracted = true;
                  },
                  onTap: (tapPosition, point) => _selectPoint(point),
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
                  StreamBuilder<DatabaseEvent>(
                    stream: _adsStream,
                    builder: (context, snapshot) {
                      final markers = <Marker>[];
                      final data = snapshot.data?.snapshot.value;
                      if (data is Map) {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        data.forEach((key, value) {
                          if (value is! Map) return;
                          final lat = value['lat'];
                          final lng = value['lng'];
                          final end = value['endTime'];
                          if (lat is! num || lng is! num || end is! num ||
                              !lat.isFinite || !lng.isFinite ||
                              lat.abs() > 90 || lng.abs() > 180 || now > end) {
                            return;
                          }
                          markers.add(Marker(
                            point: LatLng(lat.toDouble(), lng.toDouble()),
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                _userInteracted = true;
                                _showAdDetails(context, key.toString(), value);
                              },
                              child: Tooltip(
                                message: (value['category'] ?? 'Ogłoszenie').toString(),
                                child: const Icon(Icons.location_on,
                                  color: Colors.orange, size: 48),
                              ),
                            ),
                          ));
                        });
                      }
                      return MarkerLayer(markers: markers);
                    },
                  ),
                  if (_selectedPoint != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _selectedPoint!,
                        width: 52,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: IgnorePointer(
                          child: Semantics(
                            label: 'Wybrana lokalizacja: $_selectedLabel',
                            child: const Icon(Icons.location_on,
                              color: Colors.blue, size: 52,
                              shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
                          ),
                        ),
                      ),
                    ]),
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                  ),
                ],
              ),
            ),
            if (_selectedPoint != null && MediaQuery.viewInsetsOf(context).bottom == 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.place, color: Colors.blue),
                    title: Text(_selectedLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                      '${_selectedPoint!.longitude.toStringAsFixed(5)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Usuń zaznaczenie',
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            // Last in the Stack: suggestions receive taps before the map.
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (constraints.maxHeight - 100).clamp(80.0, 420.0).toDouble(),
                  ),
                  child: MapSearchBar(
                    onSelected: _selectPlace,
                    onCleared: _clearSelection,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0 ? null
          : FloatingActionButton.extended(
        onPressed: _addAtSelectedPoint,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: Text(_selectedPoint == null ? 'WYBIERZ MIEJSCE' : 'DODAJ OGŁOSZENIE TUTAJ',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showAddAdForm(BuildContext context, LatLng point) {
    if (_adFormOpen) return;
    _adFormOpen = true;
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
                return;
              }

              if (!context.mounted) {
                return; 
              }

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  isStart ? startTime : endTime,
                ),
              );

              if (time == null) {
                return; 
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
                    ); 
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
                                    "support.ACTIV.io"; 
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
                                "ownerUid": user?.uid, 
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
    ).whenComplete(() {
      _adFormOpen = false;
    });
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
                : 320, 
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
                if (isAdmin && !isMyAd && adOwnerUid != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
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
                                      .remove(); 
                                  if (context.mounted) {
                                    Navigator.pop(
                                      banCtx,
                                    ); 
                                    Navigator.pop(ctx); 
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
                                  builder: (context) => 
                                    ChatScreen(peerName: (ad["user"] ?? "Nieznany").toString()),
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
