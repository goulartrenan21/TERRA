import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000', // Android emulator → localhost
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTerritoriesInBbox(String bbox) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/map/territories',
      queryParameters: {'bbox': bbox},
    );
    return res.data!;
  }

  // ── Activities ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> postActivity({
    required Map<String, dynamic> polyline,
    required Map<String, dynamic> metrics,
    required String startedAt,
    required String endedAt,
    List<String> powersUsed = const [],
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/activities', data: {
      'polyline':   polyline,
      'metrics':    metrics,
      'startedAt':  startedAt,
      'endedAt':    endedAt,
      if (powersUsed.isNotEmpty) 'powersUsed': powersUsed,
    });
    return res.data!;
  }

  Future<Map<String, dynamic>> getActivity(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/activities/$id');
    return res.data!;
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return res.data!;
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    await _dio.patch('/me', data: data);
  }

  // ── Rankings ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRankings({
    String scope = 'neighborhood',
    String window = 'week',
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/rankings',
      queryParameters: {'scope': scope, 'window': window},
    );
    return res.data!;
  }

  // ── Feed ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFeed({String? cursor, String tab = 'explore'}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/feed',
      queryParameters: {
        'tab': tab,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return res.data!;
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getNotifications() async {
    final res = await _dio.get<List<dynamic>>('/notifications');
    return res.data!;
  }

  Future<void> markNotificationsRead(List<String> ids) async {
    await _dio.post('/notifications/read', data: {'ids': ids});
  }

  // ── Streak ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> streakCheckin() async {
    final res = await _dio.post<Map<String, dynamic>>('/streak/checkin');
    return res.data!;
  }

  // ── Devices ────────────────────────────────────────────────────────────────

  Future<void> registerDevice(String token, String platform) async {
    await _dio.post('/devices', data: {'token': token, 'platform': platform});
  }

  // ── Powers ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getPowers() async {
    final res = await _dio.get<List<dynamic>>('/powers');
    return res.data!;
  }

  Future<Map<String, dynamic>> activatePower(String kind) async {
    final res = await _dio.post<Map<String, dynamic>>('/powers/$kind/activate');
    return res.data!;
  }
}
