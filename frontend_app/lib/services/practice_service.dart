// lib/services/practice_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'server_config.dart';

class PracticeService {
  final AuthService _auth = AuthService();

  Future<Map<String, dynamic>?> simulateTurn({
    required String action,
    Map<String, dynamic>? player1State,
    Map<String, dynamic>? player2State,
  }) async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;

    try {
      final response = await http.post(
        Uri.parse('$base/simulate_practice'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'player1': 'Anda',
          'player2': 'Bot Dummy',
          'action': action,
          if (player1State != null) 'player1_state': player1State,
          if (player2State != null) 'player2_state': player2State,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Simulate error: \${response.body}');
        return null;
      }
    } catch (e) {
      print('Simulate exception: \$e');
      return null;
    }
  }
}
