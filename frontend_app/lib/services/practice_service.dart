// lib/services/practice_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      final bodyData = <String, dynamic>{
        'player1': 'Anda',
        'player2': 'Bot Dummy',
        'action': action,
      };
      if (player1State != null) bodyData['player1_state'] = player1State;
      if (player2State != null) bodyData['player2_state'] = player2State;

      final response = await http.post(
        Uri.parse('$base/simulate_practice'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Simulate error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Simulate exception: $e');
      return null;
    }
  }
}
