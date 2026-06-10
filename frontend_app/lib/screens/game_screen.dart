// lib/screens/game_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/auth_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  WebSocketChannel? _channel;
  final AuthService _authService = AuthService();
  
  String _myUsername = "";
  Map<String, dynamic> _gameState = {};
  String _statusMessage = "Menghubungkan ke server...";
  bool _isWaiting = true;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    final token = await _authService.getToken();
    if (token == null) return;

    // Decode token sederhana untuk mendapatkan username sendiri (UI purpose)
    final parts = token.split('.');
    if (parts.length == 3) {
      final payloadMap = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      _myUsername = payloadMap['username'];
    }

    // Efisiensi & Keamanan: Kirim token sebagai parameter URL
    // Ganti 127.0.0.1 menjadi IP TiDB atau tetap 127.0.0.1 jika backend jalan lokal
    final wsUrl = Uri.parse('ws://127.0.0.1:8000/ws/arena?token=$token');
    
    _channel = WebSocketChannel.connect(wsUrl);
    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        setState(() {
          if (data['type'] == 'waiting') {
            _isWaiting = true;
            _statusMessage = data['message'];
          } else if (data['type'] == 'game_state') {
            _isWaiting = false;
            _gameState = data;
            _statusMessage = data['message'] ?? "";
          }
        });
      },
      onError: (error) {
        setState(() => _statusMessage = "Koneksi terputus!");
      },
    );
  }

  void _sendAction(String action) {
    if (_channel != null && _gameState['turn'] == _myUsername) {
      // Keamanan: Client hanya mengirim niat aksi (action intent)
      _channel!.sink.add(jsonEncode({"action": action}));
    }
  }

  @override
  void dispose() {
    // Efisiensi: Mencegah memory leak socket connection
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isWaiting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matchmaking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_statusMessage, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    // Ekstrak data HP dari JSON server
    final players = _gameState['players'] as Map<String, dynamic>;
    final isMyTurn = _gameState['turn'] == _myUsername;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arena Pertarungan'),
        automaticallyImplyLeading: false, // Cegah back button saat game berlangsung
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 40),
            
            // Tampilan Status Pemain
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: players.entries.map((entry) {
                final isMe = entry.key == _myUsername;
                return Column(
                  children: [
                    Icon(isMe ? Icons.shield : Icons.warning, size: 50, color: isMe ? Colors.green : Colors.red),
                    Text(entry.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('HP: ${entry.value['hp']}', style: const TextStyle(fontSize: 24)),
                  ],
                );
              }).toList(),
            ),
            
            const Spacer(),
            
            // Indikator Giliran
            Text(
              isMyTurn ? "Giliran Anda!" : "Menunggu lawan...",
              style: TextStyle(fontSize: 22, color: isMyTurn ? Colors.green : Colors.grey),
            ),
            const SizedBox(height: 20),
            
            // Tombol Aksi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('SERANG'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                  onPressed: isMyTurn ? () => _sendAction('attack') : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.favorite),
                  label: const Text('HEAL'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                  onPressed: isMyTurn ? () => _sendAction('heal') : null,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}