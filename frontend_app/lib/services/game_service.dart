// lib/services/game_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'server_config.dart';

/// Mengelola koneksi WebSocket ke arena game.
/// Semua logika WebSocket ada di sini, bukan di screen.
class GameService {
  WebSocketChannel? _channel;
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream event game_state & action_error dari server
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  bool get isConnected => _channel != null;

  /// Buat koneksi WebSocket ke arena.
  void connect(String token) {
    final url = Uri.parse('${ServerConfig.wsUrl}/ws/arena?token=$token');
    _channel = WebSocketChannel.connect(url);
    _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _stateController.add(data);
        } catch (e) {
          // Abaikan pesan yang tidak valid JSON
        }
      },
      onError: (_) {
        _stateController.add({'type': 'error', 'message': 'Koneksi terputus!'});
      },
      onDone: () {
        _stateController.add({'type': 'disconnected', 'message': 'Server menutup koneksi.'});
      },
    );
  }

  /// Kirim aksi (attack, heal, heavy_strike, dll.) ke server.
  void sendAction(String action) {
    _channel?.sink.add(jsonEncode({'action': action}));
  }

  /// Tutup koneksi WebSocket.
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
