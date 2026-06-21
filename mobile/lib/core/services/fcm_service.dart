import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

// Must be a top-level function — called by the system in an isolate
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // System handles notification display; no action needed here
}

class FcmService {
  static Future<void> registerToken(ApiClient api) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      await api.registerDevice(token, platform);

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        api.registerDevice(newToken, platform).catchError((_) {});
      });
    } catch (e) {
      debugPrint('[fcm] registerToken error: $e');
    }
  }
}
