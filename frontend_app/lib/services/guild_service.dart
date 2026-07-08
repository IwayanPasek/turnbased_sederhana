import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'server_config.dart';

class GuildService {
  final String baseUrl = ServerConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> getGuilds() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guilds'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getGuilds: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMyGuild() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guilds/my_guild'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getMyGuild: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createGuild(String name, String description) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error createGuild: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> joinGuild(int guildId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/$guildId/join'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error joinGuild: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> leaveGuild() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/leave'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error leaveGuild: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> sendChat(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/chat'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'message': message,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error sendChat: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> kickMember(String targetUsername) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/kick'),
        headers: await _getHeaders(),
        body: jsonEncode({'target_username': targetUsername}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> promoteMember(String targetUsername) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/promote'),
        headers: await _getHeaders(),
        body: jsonEncode({'target_username': targetUsername}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> demoteMember(String targetUsername) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/demote'),
        headers: await _getHeaders(),
        body: jsonEncode({'target_username': targetUsername}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> transferLeadership(String targetUsername) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/transfer'),
        headers: await _getHeaders(),
        body: jsonEncode({'target_username': targetUsername}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> disbandGuild() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/disband'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> donateToGuild(int coins, int gems) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guilds/donate'),
        headers: await _getHeaders(),
        body: jsonEncode({'coins': coins, 'gems': gems}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('Error donateToGuild: $e');
      return {'success': false, 'detail': e.toString()};
    }
  }
}
