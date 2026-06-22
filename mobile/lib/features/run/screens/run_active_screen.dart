import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/run_session_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../map/widgets/territory_layer.dart';
import '../../powers/providers/powers_provider.dart';

class RunActiveScreen extends ConsumerStatefulWidget {
  const RunActiveScreen({super.key});

  @override
  ConsumerState<RunActiveScreen> createState() => _RunActiveScreenState();
}

class _RunActiveScreenState extends ConsumerState<RunActiveScreen> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRun());
  }

  Future<void> _startRun() async {
    final ok = await ref.read(runSessionProvider.notifier).startRun();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS não disponível. Verifique as permissões.'),
          backgroundColor: AppColors.error,
        ),
      );
      context.pop();
    }
  }

  Future<void> _stopRun() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar corrida?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(runSessionProvider.notifier).stopAndUpload();
    if (mounted) context.go('/app/map/run/capture');
  }

  @override
  Widget build(BuildContext context) {
    final run         = ref.watch(runSessionProvider);
    final territories = ref.watch(territoriesProvider);
    final lastPoint   = run.points.isNotEmpty ? run.points.last : null;

    // Keep map centered on user
    if (lastPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(lastPoint, _mapController.camera.zoom);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // ── Map with route ─────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: lastPoint ?? const LatLng(-23.55, -46.63),
              initialZoom: 17,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, // lock map during run
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.terra.mobile',
                tileBuilder: _darkTile,
              ),
              TerritoryLayer(features: territories.features),

              // Route polyline
              if (run.points.length > 1)
                PolylineLayer(polylines: [
                  Polyline(
                    points:       run.points,
                    strokeWidth:  4,
                    color:        AppColors.coral,
                  ),
                ]),

              // Detected loops highlight
              ...run.detectedLoops.map((loop) => PolygonLayer(
                polygons: [
                  Polygon(
                    points:       loop,
                    color:        AppColors.coral.withAlpha(60),
                    borderColor:  AppColors.amber,
                    borderStrokeWidth: 2,
                  ),
                ],
              )),

              // User position
              if (lastPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    point:  lastPoint,
                    width:  20,
                    height: 20,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                ]),
            ],
          ),

          // ── Top HUD ────────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16,
            child: Column(
              children: [
                _TopHud(run: run),
                if (run.armedPowers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ArmedPowersBar(kinds: run.armedPowers),
                ],
              ],
            ),
          ),

          // ── Bottom controls ────────────────────────────────────────────────
          Positioned(
            bottom: 32, left: 24, right: 24,
            child: _BottomControls(
              run: run,
              onPause:  () => ref.read(runSessionProvider.notifier).pauseRun(),
              onResume: () => ref.read(runSessionProvider.notifier).resumeRun(),
              onStop:   _stopRun,
            ),
          ),

          // ── Loop flash animation ────────────────────────────────────────────
          if (run.detectedLoops.isNotEmpty)
            const _LoopFlash(),
        ],
      ),
    );
  }

  Widget _darkTile(BuildContext ctx, Widget tile, TileImage _) =>
      ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -0.2126, -0.7152, -0.0722, 0, 255,
          -0.2126, -0.7152, -0.0722, 0, 255,
          -0.2126, -0.7152, -0.0722, 0, 255,
          0,       0,       0,       1,   0,
        ]),
        child: tile,
      );
}

class _TopHud extends StatelessWidget {
  final RunSessionState run;
  const _TopHud({required this.run});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(200),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _HudItem(label: 'TEMPO',    value: run.formattedTime,                               unit: ''),
        _HudItem(label: 'DIST',     value: run.distanceKm.toStringAsFixed(2),               unit: 'km'),
        _HudItem(label: 'LOOPS',    value: run.detectedLoops.length.toString(),              unit: '×'),
      ],
    ),
  );
}

class _HudItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _HudItem({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AppTextStyles.label(color: Colors.white54)),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: AppTextStyles.metricMedium(color: Colors.white)),
          if (unit.isNotEmpty)
            Text(' $unit', style: AppTextStyles.metricSmall(color: Colors.white60)),
        ],
      ),
    ],
  );
}

class _BottomControls extends StatelessWidget {
  final RunSessionState run;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  const _BottomControls({
    required this.run,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // Pause / Resume
      FloatingActionButton(
        heroTag: 'pause',
        backgroundColor: Colors.white.withAlpha(230),
        onPressed: run.status == RunStatus.paused ? onResume : onPause,
        child: Icon(
          run.status == RunStatus.paused ? Icons.play_arrow : Icons.pause,
          color: AppColors.tinta,
          size: 32,
        ),
      ),

      // Stop
      FloatingActionButton.large(
        heroTag:         'stop',
        backgroundColor: AppColors.coral,
        onPressed:       onStop,
        child: run.status == RunStatus.uploading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
            : const Icon(Icons.stop, color: Colors.white, size: 40),
      ),
    ],
  );
}

class _LoopFlash extends StatefulWidget {
  const _LoopFlash();

  @override
  State<_LoopFlash> createState() => _LoopFlashState();
}

class _LoopFlashState extends State<_LoopFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: (1 - _ctrl.value) * 0.4,
        child: Container(color: AppColors.coral),
      ),
    ),
  );
}

class _ArmedPowersBar extends StatelessWidget {
  final List<PowerKind> kinds;
  const _ArmedPowersBar({required this.kinds});

  static String _emoji(PowerKind k) => switch (k) {
    PowerKind.shield    => '🛡️',
    PowerKind.reclaim   => '⚡',
    PowerKind.sprint    => '🚀',
    PowerKind.roots     => '🌱',
    PowerKind.freshness => '❄️',
    PowerKind.revenge   => '🔥',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.coral.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PODERES ATIVOS  ', style: TextStyle(color: AppColors.coral, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ...kinds.map((k) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(_emoji(k), style: const TextStyle(fontSize: 16)),
        )),
      ],
    ),
  );
}
