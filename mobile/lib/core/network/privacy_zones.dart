import 'package:latlong2/latlong.dart';

class PrivacyZone {
  final double lat;
  final double lng;
  final double radiusM;

  const PrivacyZone({required this.lat, required this.lng, required this.radiusM});
}

// Truncates the route: removes points within any privacy zone from
// both the start and end of the route. Done locally, never sent to server.
List<LatLng> applyPrivacyZones(List<LatLng> points, List<PrivacyZone> zones) {
  if (zones.isEmpty || points.isEmpty) return points;

  const distance = Distance();

  int startIdx = 0;
  int endIdx   = points.length - 1;

  // Trim from start
  for (var i = 0; i < points.length; i++) {
    final inZone = zones.any((z) =>
      distance.as(LengthUnit.Meter, points[i], LatLng(z.lat, z.lng)) <= z.radiusM,
    );
    if (!inZone) { startIdx = i; break; }
  }

  // Trim from end
  for (var i = points.length - 1; i >= startIdx; i--) {
    final inZone = zones.any((z) =>
      distance.as(LengthUnit.Meter, points[i], LatLng(z.lat, z.lng)) <= z.radiusM,
    );
    if (!inZone) { endIdx = i; break; }
  }

  if (startIdx >= endIdx) return [];
  return points.sublist(startIdx, endIdx + 1);
}
