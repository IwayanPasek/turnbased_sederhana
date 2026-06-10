// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Efisiensi & Jaringan: Gunakan 127.0.0.1 untuk aplikasi desktop (Windows/Mac/Linux) 
  // yang berjalan di mesin yang sama dengan server lokal.
  static const String baseUrl = 'http://127.0.0.1:8000'; 
  
  final _storage = const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Fungsi Login
  // ---------------------------------------------------------------------------
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        // Keamanan: Pastikan data credentials dikirim via POST body
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Keamanan: Token disimpan ke dalam Keystore/Keychain OS
        await _storage.write(key: 'jwt_token', value: data['access_token']);
        return true;
      }
      return false;
    } catch (e) {
      // Efisiensi Debugging: Cetak error ke konsol IDE agar tidak gagal secara "bisu"
      print('Error Auth: $e'); 
      return false;
    }
    
  }

  // ---------------------------------------------------------------------------
  // Fungsi Register (Yang baru saja ditambahkan)
  // ---------------------------------------------------------------------------
  Future<bool> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      // Menerima 200 atau 201 (Created) dari backend sebagai indikator sukses
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      // Efisiensi Debugging: Cetak error ke konsol IDE agar tidak gagal secara "bisu"
      print('Error Auth: $e'); 
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Fungsi Logout
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    // Keamanan: Bersihkan kredensial lokal secara total saat pengguna keluar
    await _storage.delete(key: 'jwt_token');
  }

  // ---------------------------------------------------------------------------
  // Fungsi Pengecekan Sesi Aktif
  // ---------------------------------------------------------------------------
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
} // <-- Pastikan kurung kurawal penutup class ini ada di paling bawah