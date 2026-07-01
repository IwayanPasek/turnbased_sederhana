// lib/providers/profile_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/stats_service.dart';

/// State profil pemain
class ProfileNotifier extends ChangeNotifier {
  final _auth = AuthService();
  final _stats = StatsService();

  AsyncValue<Map<String, dynamic>> state = const AsyncValue.loading();

  void _setState(AsyncValue<Map<String, dynamic>> newState) {
    state = newState;
    notifyListeners();
  }

  Future<void> load() async {
    _setState(const AsyncValue.loading());
    try {
      final token = await _auth.getToken();
      if (token == null) {
        _setState(AsyncValue.error('No token', StackTrace.current));
        return;
      }
      final data = await _stats.getPlayerStats(token);
      if (data != null) {
        _setState(AsyncValue.data(data));
      } else {
        _setState(AsyncValue.error('Gagal memuat profil', StackTrace.current));
      }
    } catch (e, st) {
      _setState(AsyncValue.error(e, st));
    }
  }

  void reset() => _setState(const AsyncValue.loading());
}

final profileNotifier = ProfileNotifier();
