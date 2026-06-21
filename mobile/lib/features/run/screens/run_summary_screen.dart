import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/run_session_provider.dart';

class RunSummaryScreen extends ConsumerWidget {
  final String activityId;
  const RunSummaryScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Resumo da Corrida', style: AppTextStyles.title()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(runSessionProvider.notifier).reset();
            context.go('/app/map');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Route map ───────────────────────────────────────────────────
            _RouteMap(points: run.points),
            const SizedBox(height: 20),

            // ── Metrics grid ─────────────────────────────────────────────────
            _MetricsGrid(run: run),
            const SizedBox(height: 24),

            // ── Post to feed ─────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () {
                // TODO Phase 8: share activity to feed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Atividade postada no feed!')),
                );
                context.go('/app/feed');
              },
              icon:  const Icon(Icons.share_outlined),
              label: const Text('Postar no Feed'),
            ),
            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () {
                ref.read(runSessionProvider.notifier).reset();
                context.go('/app/map');
              },
              child: const Text('Voltar ao Mapa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  final List<LatLng> points;
  const _RouteMap({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color:        AppColors.bgLight,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: const Color(0xFFD0C8BF)),
        ),
        child: const Center(child: Icon(Icons.map_outlined, size: 48, color: AppColors.sage)),
      );
    }

    final bounds = LatLngBounds.fromPoints(points);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(32),
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            PolylineLayer(polylines: [
              Polyline(points: points, strokeWidth: 4, color: AppColors.coral),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final RunSessionState run;
  const _MetricsGrid({required this.run});

  @override
  Widget build(BuildContext context) {
    final paceTotal = run.avgPaceSecPerKm.round();
    final paceStr = '${paceTotal ~/ 60}\'${(paceTotal % 60).toString().padLeft(2, '0')}"';

    return GridView.count(
      crossAxisCount:  2,
      shrinkWrap:      true,
      physics:         const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing:  12,
      childAspectRatio: 1.6,
      children: [
        _MetricCard(label: 'Distância',  value: '${run.distanceKm.toStringAsFixed(2)} km'),
        _MetricCard(label: 'Tempo',      value: run.formattedTime),
        _MetricCard(label: 'Pace médio', value: paceStr),
        _MetricCard(label: 'Loops',      value: '${run.detectedLoops.length}'),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,  style: AppTextStyles.label()),
        const SizedBox(height: 4),
        Text(value,  style: AppTextStyles.metric(size: 22)),
      ],
    ),
  );
}
