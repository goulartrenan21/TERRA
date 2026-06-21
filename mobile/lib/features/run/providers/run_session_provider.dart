import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/privacy_zones.dart' as pz;

enum RunStatus { idle, running, paused, uploading, done, error }

class RunSessionState {
  final RunStatus status;
  final List<LatLng> points;
  final double distanceM;
  final int elapsedSeconds;
  final List<List<LatLng>> detectedLoops;
  final String? uploadedActivityId;
  final String? errorMessage;
  final DateTime? startedAt;

  const RunSessionState({
    this.status          = RunStatus.idle,
    this.points          = const [],
    this.distanceM       = 0,
    this.elapsedSeconds  = 0,
    this.detectedLoops   = const [],
    this.uploadedActivityId,
    this.errorMessage,
    this.startedAt,
  });

  RunSessionState copyWith({
    RunStatus? status,
    List<LatLng>? points,
    double? distanceM,
    int? elapsedSeconds,
    List<List<LatLng>>? detectedLoops,
    String? uploadedActivityId,
    String? errorMessage,
    DateTime? startedAt,
  }) => RunSessionState(
    status:              status ?? this.status,
    points:              points ?? this.points,
    distanceM:           distanceM ?? this.distanceM,
    elapsedSeconds:      elapsedSeconds ?? this.elapsedSeconds,
    detectedLoops:       detectedLoops ?? this.detectedLoops,
    uploadedActivityId:  uploadedActivityId ?? this.uploadedActivityId,
    errorMessage:        errorMessage ?? this.errorMessage,
    startedAt:           startedAt ?? this.startedAt,
  );

  double get distanceKm => distanceM / 1000;
  String get formattedTime {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get avgPaceSecPerKm =>
      distanceKm > 0 ? elapsedSeconds / distanceKm : 0;
}

final runSessionProvider =
    StateNotifierProvider<RunSessionNotifier, RunSessionState>(
  (ref) => RunSessionNotifier(ref.read(apiClientProvider)),
);

class RunSessionNotifier extends StateNotifier<RunSessionState> {
  final ApiClient _api;

  StreamSubscription<Position>? _gpsSub;
  Timer? _clockTimer;
  Timer? _pauseTimer;

  static const _minSpeedForPause = 0.5; // m/s
  static const _pauseAfterSeconds = 60;

  RunSessionNotifier(this._api) : super(const RunSessionState());

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<bool> startRun() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: RunStatus.error,
        errorMessage: 'Permissão de localização negada.',
      );
      return false;
    }

    state = RunSessionState(
      status:    RunStatus.running,
      startedAt: DateTime.now(),
    );

    _startClock();
    _startGps();
    return true;
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  void pauseRun() {
    _gpsSub?.pause();
    _clockTimer?.cancel();
    _pauseTimer?.cancel();
    state = state.copyWith(status: RunStatus.paused);
  }

  void resumeRun() {
    _gpsSub?.resume();
    _startClock();
    state = state.copyWith(status: RunStatus.running);
  }

  void suggestPause() {
    // Called after 60s below speed threshold — UI shows pause suggestion dialog
    state = state.copyWith(status: RunStatus.paused);
    pauseRun();
  }

  // ── Stop + Upload ──────────────────────────────────────────────────────────

  Future<void> stopAndUpload({List<pz.PrivacyZone> privacyZones = const []}) async {
    _gpsSub?.cancel();
    _clockTimer?.cancel();
    _pauseTimer?.cancel();

    if (state.points.length < 4) {
      state = state.copyWith(status: RunStatus.error, errorMessage: 'Percurso muito curto.');
      return;
    }

    state = state.copyWith(status: RunStatus.uploading);

    try {
      final sanitized = pz.applyPrivacyZones(state.points, privacyZones);
      final coords    = sanitized.map((p) => [p.longitude, p.latitude]).toList();

      final result = await _api.postActivity(
        polyline:  {'type': 'LineString', 'coordinates': coords},
        metrics:   {
          'distanceM':       state.distanceM,
          'durationS':       state.elapsedSeconds,
          'avgPaceSecPerKm': state.avgPaceSecPerKm,
        },
        startedAt: state.startedAt!.toUtc().toIso8601String(),
        endedAt:   DateTime.now().toUtc().toIso8601String(),
      );

      state = state.copyWith(
        status:             RunStatus.done,
        uploadedActivityId: result['activityId'] as String,
      );
    } catch (e) {
      state = state.copyWith(status: RunStatus.error, errorMessage: e.toString());
    }
  }

  void reset() => state = const RunSessionState();

  // ── Internal ───────────────────────────────────────────────────────────────

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _startGps() {
    const settings = LocationSettings(
      accuracy:         LocationAccuracy.high,
      distanceFilter:   5, // emit every 5m minimum
    );

    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => _onPosition(pos),
    );
  }

  void _onPosition(Position pos) {
    if (state.status != RunStatus.running) return;

    final newPoint  = LatLng(pos.latitude, pos.longitude);
    final newPoints = [...state.points, newPoint];

    // Distance delta
    double delta = 0;
    if (state.points.isNotEmpty) {
      delta = Geolocator.distanceBetween(
        state.points.last.latitude, state.points.last.longitude,
        pos.latitude, pos.longitude,
      );
    }

    // Auto-pause check
    final speed = pos.speed; // m/s
    if (speed < _minSpeedForPause) {
      _pauseTimer ??= Timer(
        const Duration(seconds: _pauseAfterSeconds),
        suggestPause,
      );
    } else {
      _pauseTimer?.cancel();
      _pauseTimer = null;
    }

    // Quick loop detection for visual feedback (not for capture — server does that)
    final loops = _quickDetectLoops(newPoints);

    state = state.copyWith(
      points:        newPoints,
      distanceM:     state.distanceM + delta,
      detectedLoops: loops,
    );
  }

  // Simplified client-side loop detection for real-time visual feedback only
  List<List<LatLng>> _quickDetectLoops(List<LatLng> points) {
    if (points.length < 6) return [];
    // Check last segment against older segments (skip last 3 to avoid false positives)
    final last = points[points.length - 1];
    final prev = points[points.length - 2];
    final loops = <List<LatLng>>[];

    for (var i = 0; i < points.length - 4; i++) {
      final crossing = _segmentIntersect(prev, last, points[i], points[i + 1]);
      if (crossing != null) {
        loops.add([crossing, ...points.sublist(i + 1, points.length - 1), crossing]);
      }
    }
    return loops;
  }

  LatLng? _segmentIntersect(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    final x1 = p1.longitude; final y1 = p1.latitude;
    final x2 = p2.longitude; final y2 = p2.latitude;
    final x3 = p3.longitude; final y3 = p3.latitude;
    final x4 = p4.longitude; final y4 = p4.latitude;

    final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denom.abs() < 1e-10) return null;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    final u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom;

    if (t > 0.001 && t < 0.999 && u > 0.001 && u < 0.999) {
      return LatLng(y1 + t * (y2 - y1), x1 + t * (x2 - x1));
    }
    return null;
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _clockTimer?.cancel();
    _pauseTimer?.cancel();
    super.dispose();
  }
}
