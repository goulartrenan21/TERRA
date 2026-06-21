import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/map_provider.dart';
import '../widgets/territory_layer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  LatLng? _userPosition;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) { return; }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userPosition = loc);
      if (_followUser) { _mapController.move(loc, _mapController.camera.zoom); }
    });

    // Initial position
    final pos = await Geolocator.getCurrentPosition();
    final loc = LatLng(pos.latitude, pos.longitude);
    setState(() => _userPosition = loc);
    _mapController.move(loc, 16);
    _fetchTerritories();
  }

  void _fetchTerritories() {
    final bounds = _mapController.camera.visibleBounds;
    ref.read(territoriesProvider.notifier).fetchForBounds(bounds);
  }

  @override
  Widget build(BuildContext context) {
    final territories = ref.watch(territoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? const LatLng(-23.55, -46.63),
              initialZoom:   16,
              onPositionChanged: (_, __) {
                setState(() => _followUser = false);
                _fetchTerritories();
              },
            ),
            children: [
              // OSM tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.terra.mobile',
                tileBuilder: _darkModeTileBuilder,
              ),

              // Territory polygons
              TerritoryLayer(features: territories.features),

              // User position marker
              if (_userPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point:  _userPosition!,
                    width:  24,
                    height: 24,
                    child:  _UserPositionMarker(),
                  ),
                ]),
            ],
          ),

          // ── Top mini-ranking ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _MiniRanking(),
          ),

          // ── Recenter button ─────────────────────────────────────────────────
          if (!_followUser)
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white.withAlpha(230),
                onPressed: () {
                  if (_userPosition != null) {
                    _mapController.move(_userPosition!, _mapController.camera.zoom);
                    setState(() => _followUser = true);
                  }
                },
                child: const Icon(Icons.my_location, color: AppColors.tinta),
              ),
            ),

          // ── Loading indicator ────────────────────────────────────────────────
          if (territories.isLoading)
            const Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                ),
              ),
            ),
        ],
      ),

      // ── FAB — Iniciar corrida ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/app/map/run/active'),
        backgroundColor: AppColors.coral,
        icon:  const Icon(Icons.directions_run, color: Colors.white),
        label: Text('CORRER', style: AppTextStyles.button()),
      ),
    );
  }

  Widget _darkModeTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -0.2126, -0.7152, -0.0722, 0, 255,
        -0.2126, -0.7152, -0.0722, 0, 255,
        -0.2126, -0.7152, -0.0722, 0, 255,
        0,       0,       0,       1,   0,
      ]),
      child: tileWidget,
    );
  }
}

class _UserPositionMarker extends StatefulWidget {
  @override
  State<_UserPositionMarker> createState() => _UserPositionMarkerState();
}

class _UserPositionMarkerState extends State<_UserPositionMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (_, __) => Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width:  24 * _pulse.value,
          height: 24 * _pulse.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.coral.withAlpha((0.25 * 255).round()),
          ),
        ),
        Container(
          width: 14, height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.coral,
          ),
        ),
      ],
    ),
  );
}

class _MiniRanking extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(180),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bairro esta semana', style: AppTextStyles.label(color: Colors.white54)),
        const SizedBox(height: 4),
        _RankRow(position: 1, name: '—', area: '—'),
        _RankRow(position: 2, name: '—', area: '—'),
        _RankRow(position: 3, name: '—', area: '—'),
      ],
    ),
  );
}

class _RankRow extends StatelessWidget {
  final int position;
  final String name;
  final String area;
  const _RankRow({required this.position, required this.name, required this.area});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$position. ', style: AppTextStyles.metricSmall(color: AppColors.coral)),
      Text(name, style: AppTextStyles.label(color: Colors.white70)),
      const SizedBox(width: 8),
      Text(area, style: AppTextStyles.metricSmall(color: Colors.white70)),
    ],
  );
}
