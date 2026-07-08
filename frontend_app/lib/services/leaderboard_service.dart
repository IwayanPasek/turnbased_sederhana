import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'server_config.dart';

class LeaderboardService {
  final String baseUrl = ServerConfig.baseUrl;

  Future<List<dynamic>?> getLeaderboard({int limit = 100}) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/leaderboard?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['leaderboard'] as List<dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error getLeaderboard: $e');
      return null;
    }
  }
}
