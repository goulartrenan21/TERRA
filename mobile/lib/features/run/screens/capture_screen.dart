import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/run_session_provider.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  late ConfettiController _confetti;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  // Capture result from WebSocket
  double _capturedKm2 = 0;
  int    _xpGained    = 0;
  bool   _leveledUp   = false;
  int    _newLevel    = 1;
  List<Map<String, dynamic>> _stolenFrom = [];
  bool   _received    = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    _listenForCapture();
    _schedulePollingFallback();
  }

  void _listenForCapture() {
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.messagesOfType('capture_done').listen((msg) {
      if (!mounted) return;
      final payload = msg['payload'] as Map<String, dynamic>? ?? {};
      _applyResult(payload);
    });
  }

  // If WS doesn't arrive in 30s, poll /activities/:id
  void _schedulePollingFallback() {
    Future.delayed(const Duration(seconds: 30), () async {
      if (!mounted || _received) return;
      final activityId = ref.read(runSessionProvider).uploadedActivityId;
      if (activityId == null) return;
      try {
        final api = ref.read(apiClientProvider);
        final data = await api.getActivity(activityId);
        if (data['status'] == 'done' && mounted) {
          _applyResult(const {});
        }
      } catch (_) {}
    });
  }

  void _applyResult(Map<String, dynamic> payload) {
    final capturedAreas = (payload['capturedAreas'] as List<dynamic>?) ?? [];
    final totalArea = capturedAreas.fold<double>(
      0, (sum, a) => sum + ((a as Map)['areaKm2'] as num).toDouble(),
    );

    setState(() {
      _capturedKm2 = totalArea;
      _xpGained    = (payload['xpGained'] as num?)?.toInt() ?? 0;
      _leveledUp   = (payload['leveledUp'] as bool?) ?? false;
      _newLevel    = (payload['newLevel'] as num?)?.toInt() ?? 1;
      _stolenFrom  = ((payload['stolenFrom'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      _received    = true;
    });

    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ── Confetti ───────────────────────────────────────────────────────
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [AppColors.coral, AppColors.amber, Colors.white, AppColors.sage],
            numberOfParticles: 40,
            gravity: 0.3,
          ),

          SafeArea(
            child: _received ? _CaptureResult(
              capturedKm2: _capturedKm2,
              xpGained:    _xpGained,
              leveledUp:   _leveledUp,
              newLevel:    _newLevel,
              stolenFrom:  _stolenFrom,
              onViewMap:   () => context.go('/app/map'),
              onPost:      () => context.go('/run/summary/${ref.read(runSessionProvider).uploadedActivityId ?? ''}'),
            ) : _WaitingCapture(),
          ),
        ],
      ),
    );
  }
}

class _WaitingCapture extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: AppColors.coral),
      const SizedBox(height: 24),
      Text('Calculando território...', style: AppTextStyles.title(color: AppColors.textOnDark)),
      const SizedBox(height: 8),
      Text('Isso leva menos de 5 segundos', style: AppTextStyles.subtitle(color: Colors.white54)),
    ],
  );
}

class _CaptureResult extends StatelessWidget {
  final double capturedKm2;
  final int    xpGained;
  final bool   leveledUp;
  final int    newLevel;
  final List<Map<String, dynamic>> stolenFrom;
  final VoidCallback onViewMap;
  final VoidCallback onPost;

  const _CaptureResult({
    required this.capturedKm2,
    required this.xpGained,
    required this.leveledUp,
    required this.newLevel,
    required this.stolenFrom,
    required this.onViewMap,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Territory icon ──────────────────────────────────────────────────
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape:       BoxShape.circle,
            color:       AppColors.coral.withAlpha(30),
            border:      Border.all(color: AppColors.coral, width: 2),
          ),
          child: const Icon(Icons.terrain, color: AppColors.coral, size: 52),
        ),
        const SizedBox(height: 24),

        Text('Território conquistado!', style: AppTextStyles.title(size: 22, color: AppColors.textOnDark)),
        const SizedBox(height: 32),

        // ── Area ────────────────────────────────────────────────────────────
        Text(
          '+${capturedKm2.toStringAsFixed(3)} km²',
          style: AppTextStyles.metricLarge(color: AppColors.coral),
        ),

        const SizedBox(height: 12),

        // ── XP ──────────────────────────────────────────────────────────────
        Text(
          '+$xpGained XP',
          style: AppTextStyles.metricMedium(color: AppColors.amber),
        ),

        // ── Level up badge ──────────────────────────────────────────────────
        if (leveledUp) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:        AppColors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: AppColors.amber),
            ),
            child: Text(
              '🎉 Nível $newLevel desbloqueado!',
              style: AppTextStyles.body(color: AppColors.amber, weight: FontWeight.w700),
            ),
          ),
        ],

        // ── Stolen territories ──────────────────────────────────────────────
        if (stolenFrom.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...stolenFrom.map((s) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Você roubou ${(s['areaKm2'] as num).toStringAsFixed(3)} km² de @${s['fromDisplayName']}',
              style: AppTextStyles.label(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          )),
        ],

        const SizedBox(height: 40),

        // ── Actions ─────────────────────────────────────────────────────────
        ElevatedButton.icon(
          onPressed: onViewMap,
          icon:  const Icon(Icons.map_outlined),
          label: const Text('Ver no Mapa'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPost,
          icon:  const Icon(Icons.share_outlined),
          label: const Text('Postar no Feed'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnDark,
            side: const BorderSide(color: Colors.white38),
          ),
        ),
      ],
    ),
  );
}
