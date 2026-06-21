import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';

// Territories GeoJSON keyed by bbox string
final territoriesProvider = StateNotifierProvider<TerritoriesNotifier, TerritoriesState>(
  (ref) => TerritoriesNotifier(ref.read(apiClientProvider)),
);

class TerritoriesState {
  final List<TerritoryFeature> features;
  final bool isLoading;
  final String? error;

  const TerritoriesState({
    this.features = const [],
    this.isLoading = false,
    this.error,
  });

  TerritoriesState copyWith({
    List<TerritoryFeature>? features,
    bool? isLoading,
    String? error,
  }) => TerritoriesState(
    features: features ?? this.features,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class TerritoryFeature {
  final String id;
  final String? ownerId;
  final String? ownerName;
  final double areaKm2;
  final double freshness;
  final List<LatLng> points; // polygon ring

  const TerritoryFeature({
    required this.id,
    this.ownerId,
    this.ownerName,
    required this.areaKm2,
    required this.freshness,
    required this.points,
  });
}

class TerritoriesNotifier extends StateNotifier<TerritoriesState> {
  final ApiClient _api;
  Timer? _debounce;

  TerritoriesNotifier(this._api) : super(const TerritoriesState());

  void fetchForBounds(LatLngBounds bounds) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _fetch(bounds));
  }

  Future<void> _fetch(LatLngBounds bounds) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final bbox =
          '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';
      final geojson = await _api.getTerritoriesInBbox(bbox);
      final features = _parseFeatures(geojson);
      state = state.copyWith(features: features, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<TerritoryFeature> _parseFeatures(Map<String, dynamic> geojson) {
    final rawFeatures = geojson['features'] as List<dynamic>? ?? [];
    return rawFeatures.map((f) {
      final props = f['properties'] as Map<String, dynamic>;
      final coords =
          (f['geometry']['coordinates'][0] as List<dynamic>)
              .map((c) => LatLng(
                    (c as List<dynamic>)[1] as double,
                    c[0] as double,
                  ))
              .toList();
      return TerritoryFeature(
        id:        props['id'] as String,
        ownerId:   props['ownerId'] as String?,
        ownerName: props['ownerName'] as String?,
        areaKm2:   (props['areaKm2'] as num).toDouble(),
        freshness: (props['freshness'] as num).toDouble(),
        points:    coords,
      );
    }).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
