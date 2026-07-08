// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'server_config.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  // Fungsi Login
  Future<String?> login(String username, String password) async {
    try {
      // Efisiensi: Mengambil baseUrl secara dinamis tanpa hardcode IP/Domain
      final response = await http.post(
        Uri.parse('${ServerConfig.baseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Keamanan: Menyimpan token secara terenkripsi menggunakan sub-sistem OS
        await _storage.write(key: 'jwt_token', value: data['access_token']);
        return null; // null = success
      }
      
      try {
        final data = jsonDecode(response.body);
        final detail = data['detail'];
        if (detail is List) {
          return 'Format username atau password tidak sesuai aturan sistem.';
        }
        return detail?.toString() ?? 'Login gagal. Silakan coba lagi.';
      } catch (_) {
        return 'Gagal terhubung dengan server (Status: ${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Error Login: $e');
      if (e is ArgumentError && e.toString().contains('No host specified')) {
        return 'URL server belum dikonfigurasi dengan benar. Silakan atur ulang.';
      }
      return 'Gagal terhubung dengan jaringan: $e';
    }
  }

  // Fungsi Registrasi Akun baru
  Future<bool> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ServerConfig.baseUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error Register: $e');
      return false;
    }
  }

  // Fungsi Penghapusan Sesi (Logout)
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  // Fungsi Mengambil Token Sesi Aktif
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Fungsi Mengambil Statistik Pemain dari Server
  Future<Map<String, dynamic>?> getPlayerStats() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ServerConfig.baseUrl}/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching player stats: $e');
      return null;
    }
  }

  // Fungsi Mengambil Username dari JWT Token
  Future<String?> getUsername() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payloadMap = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payloadMap['username'] as String?;
    } catch (e) {
      debugPrint('Error extracting username: $e');
      return null;
    }
  }

  // Fungsi Mengambil Atribut Pemain
  Future<Map<String, dynamic>?> getAttributes() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ServerConfig.baseUrl}/attributes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching attributes: $e');
      return null;
    }
  }

  // Fungsi Mengalokasikan Poin Atribut
  Future<bool> allocateAttribute(String statName, {int points = 1}) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ServerConfig.baseUrl}/attributes/allocate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'stat_name': statName,
          'points': points,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error allocating attribute: $e');
      return false;
    }
  }

  // Fungsi Mengambil Riwayat Pertarungan
  Future<List<dynamic>?> getMatchHistory() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ServerConfig.baseUrl}/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['history'] as List<dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching match history: $e');
      return null;
    }
  }
}
