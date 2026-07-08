// lib/services/stats_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'server_config.dart';

/// Service untuk mengambil statistik pemain dari API backend.
class StatsService {
  Future<Map<String, dynamic>?> getPlayerStats(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${ServerConfig.baseUrl}/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSkillsInfo() async {
    try {
      final res = await http.get(
        Uri.parse('${ServerConfig.baseUrl}/game/skills'), // BUG-12 fix: was /skills/info
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateAvatar(String token, String avatarStyle) async {
    try {
      final res = await http.post(
        Uri.parse('${ServerConfig.baseUrl}/profile/avatar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'avatar_style': avatarStyle}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
