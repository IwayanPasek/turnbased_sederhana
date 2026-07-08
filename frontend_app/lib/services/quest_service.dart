import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'server_config.dart';

class QuestService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getDailyQuests() async {
    final baseUrl = ServerConfig.baseUrl;
    final response = await http.get(
      Uri.parse('$baseUrl/daily_quests'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['quests'] ?? [];
    } else {
      throw Exception('Gagal memuat misi harian');
    }
  }

  Future<Map<String, dynamic>> claimQuest(int questId) async {
    final baseUrl = ServerConfig.baseUrl;
    final response = await http.post(
      Uri.parse('$baseUrl/daily_quests/$questId/claim'),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Gagal klaim hadiah');
    }
  }
}
