import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'server_config.dart';

class AdminService {
  final AuthService _auth = AuthService();
  final String baseUrl = ServerConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>?> getUsers({String? search}) async {
    try {
      final queryParam = search != null && search.isNotEmpty ? '?search=${Uri.encodeComponent(search)}' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users$queryParam'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['users'] as List<dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getUsers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> giveItem(int userId, int itemId, int level, int amount) async {
    try {
      final token = await _auth.getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/give-item'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'item_id': itemId, 'level': level, 'amount': amount}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return jsonDecode(response.body); // Untuk mengambil pesan error API
    } catch (e) {
      debugPrint('Error giveItem: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> broadcastMessage(String message) async {
    try {
      final token = await _auth.getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/broadcast'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error broadcastMessage: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleBan(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/ban'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error toggleBan: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> giveCurrency(int userId, int coins, int gems) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/give'),
        headers: await _getHeaders(),
        body: jsonEncode({'coins': coins, 'gems': gems}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error giveCurrency: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> toggleAdmin(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/toggle_admin'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error toggleAdmin: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> resetStats(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/reset_stats'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error resetStats: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> resetPassword(int userId, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/reset_password'),
        headers: await _getHeaders(),
        body: jsonEncode({'new_password': newPassword}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error resetPassword: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/stats'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getStats: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getUserInventory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users/$userId/inventory'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['inventory'] as List<dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getUserInventory: $e');
      return null;
    }
  }
}
