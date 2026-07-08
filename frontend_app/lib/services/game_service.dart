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

  String? _lastToken;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 2);

  /// Stream event game_state & action_error dari server
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  bool get isConnected => _channel != null;

  /// Buat koneksi WebSocket ke arena.
  void connect(String token) {
    _lastToken = token;
    _reconnectAttempts = 0;
    _doConnect(token);
  }

  void _doConnect(String token) {
    final url = Uri.parse('${ServerConfig.wsUrl}/ws/arena?token=$token');
    _channel = WebSocketChannel.connect(url);
    _channel!.stream.listen(
      (raw) {
        _reconnectAttempts = 0; // reset counter on successful message
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _stateController.add(data);
        } catch (e) {
          // Abaikan pesan yang tidak valid JSON
        }
      },
      onError: (_) {
        _channel = null;
        _tryReconnect();
      },
      onDone: () {
        _channel = null;
        // Hanya coba reconnect jika bukan disconnect yang disengaja
        if (_lastToken != null) {
          _tryReconnect();
        } else {
          _stateController.add({'type': 'disconnected', 'message': 'Server menutup koneksi.'});
        }
      },
    );
  }

  void _tryReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts || _lastToken == null) {
      _stateController.add({'type': 'disconnected', 'message': 'Koneksi terputus setelah $_reconnectAttempts percobaan.'});
      return;
    }
    _reconnectAttempts++;
    _stateController.add({'type': 'waiting', 'message': 'Mencoba sambung ulang ($_reconnectAttempts/$_maxReconnectAttempts)...'});
    Future.delayed(_reconnectDelay, () {
      if (_lastToken != null) {
        _doConnect(_lastToken!);
      }
    });
  }

  /// Kirim aksi (attack, heal, heavy_strike, dll.) ke server.
  void sendAction(String action) {
    _channel?.sink.add(jsonEncode({'action': action}));
  }

  /// Tutup koneksi WebSocket (disengaja — tidak trigger auto-reconnect).
  void disconnect() {
    _lastToken = null; // Tandai sebagai disconnect yang disengaja
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
