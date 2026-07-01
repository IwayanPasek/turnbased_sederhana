// lib/providers/game_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../services/auth_service.dart';
import '../core/utils/jwt_utils.dart';

/// State untuk game arena
class GameNotifier extends ChangeNotifier {
  final _service = GameService();
  final _auth = AuthService();
  StreamSubscription<Map<String, dynamic>>? _sub;

  String myUsername = '';
  final List<String> battleLog = [];
  bool isWaiting = true;

  AsyncValue<GameState> state = const AsyncValue.loading();

  void _setState(AsyncValue<GameState> newState) {
    state = newState;
    notifyListeners();
  }

  Future<void> connect() async {
    _setState(const AsyncValue.loading());
    final token = await _auth.getToken();
    if (token == null) {
      _setState(AsyncValue.error('Sesi tidak valid', StackTrace.current));
      return;
    }

    myUsername = JwtUtils.getUsername(token) ?? '';
    _service.connect(token);

    _sub = _service.stateStream.listen((data) {
      final type = data['type'] as String? ?? '';
      if (type == 'waiting') {
        isWaiting = true;
        _setState(AsyncValue.data(GameState.initial()));
      } else if (type == 'game_state') {
        isWaiting = false;
        final gs = GameState.fromJson(data);
        if (gs.message.isNotEmpty) {
          battleLog.insert(0, gs.message);
          if (battleLog.length > 50) battleLog.removeLast();
        }
        _setState(AsyncValue.data(gs));
      } else if (type == 'action_error') {
        final msg = data['message'] as String? ?? 'Error';
        battleLog.insert(0, '⚠️ $msg');
        _setState(AsyncValue.data(state.value ?? GameState.initial()));
      } else if (type == 'disconnected' || type == 'error') {
        isWaiting = false;
        final msg = data['message'] as String? ?? 'Koneksi terputus';
        battleLog.insert(0, '❌ $msg');
        _setState(AsyncValue.error(msg, StackTrace.current));
      }
    });
  }

  void sendAction(String action) {
    _service.sendAction(action);
  }
  
  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final gameNotifier = GameNotifier();
