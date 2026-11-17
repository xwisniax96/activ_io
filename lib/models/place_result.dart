import 'package:latlong2/latlong.dart';

class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.point,
    this.kind = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final LatLng point;
  final String kind;

  String get label => subtitle.isEmpty ? title : '$title, $subtitle';

  double get zoom => switch (kind) {
    'country' || 'state' => 8,
    'county' => 10,
    'city' || 'postcode' => 12,
    'district' || 'suburb' => 14,
    'street' => 16,
    _ => 17,
  };

  static PlaceResult? fromGeoapify(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    String text(String key) => value[key] is String
        ? (value[key] as String).trim()
        : '';
    double? coordinate(String key) {
      final raw = value[key];
      return raw is num ? raw.toDouble() : double.tryParse('$raw');
    }

    final lat = coordinate('lat');
    final lon = coordinate('lon');
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite ||
        lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    final street = [text('street'), text('housenumber')]
        .where((part) => part.isNotEmpty).join(' ');
    final city = [text('city'), text('town'), text('village'), text('municipality')]
        .where((part) => part.isNotEmpty).firstOrNull ?? '';
    final title = [text('name'), street, text('address_line1'), city, text('formatted')]
        .where((part) => part.isNotEmpty).firstOrNull;
    if (title == null) return null;
    final subtitle = [
      if (street.isNotEmpty && street != title) street,
      if (city.isNotEmpty && city != title) city,
      if (city == title || city.isEmpty) text('state'),
    ].where((part) => part.isNotEmpty && part != title).toSet().join(', ');
    return PlaceResult(
      id: text('place_id').isNotEmpty ? text('place_id') : '$lat:$lon:$title',
      title: title,
      subtitle: subtitle,
      point: LatLng(lat, lon),
      kind: text('result_type'),
    );
  }
}
