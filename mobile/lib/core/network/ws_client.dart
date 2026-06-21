import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _wsBaseUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://10.0.2.2:3000',
);

final wsClientProvider = Provider<WsClient>((ref) => WsClient());

class WsClient {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final uri = Uri.parse('$_wsBaseUrl/ws');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        if (data is String) {
          try {
            final msg = jsonDecode(data) as Map<String, dynamic>;
            _controller.add(msg);
          } catch (_) {}
        }
      },
      onDone: () => Future.delayed(const Duration(seconds: 3), connect),
      onError: (_) => Future.delayed(const Duration(seconds: 5), connect),
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  Stream<Map<String, dynamic>> messagesOfType(String type) =>
      messages.where((m) => m['type'] == type);

  void dispose() {
    disconnect();
    _controller.close();
  }
}
