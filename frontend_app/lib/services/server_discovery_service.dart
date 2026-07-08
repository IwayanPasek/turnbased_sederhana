import 'dart:async';
import 'package:http/http.dart' as http;

class ServerDiscoveryService {
  // Ganti URL ini dengan URL raw Gist atau Pastebin milik Anda.
  // Pastikan file tersebut hanya berisi teks URL ngrok (misal: https://1234-abcd.ngrok.app)
  static const String registryUrl = 'https://raw.githubusercontent.com/IwayanPasek/turnbased_sederhana/main/server_url.txt'; 
  
  /// Mengambil URL server dari Centralized Registry (Otomatis)
  static Future<String?> fetchFromRegistry() async {
    try {
      final response = await http.get(Uri.parse(registryUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final url = response.body.trim();
        if (url.startsWith('http')) {
          // Lakukan ping sederhana ke URL tersebut untuk memastikan server hidup
          final isAlive = await pingServer(url);
          if (isAlive) return url;
        }
      }
    } catch (e) {
      // Abaikan error jika gagal (misal tidak ada internet atau file tidak ditemukan)
    }
    return null;
  }

  /// Melakukan ping sederhana ke server
  static Future<bool> pingServer(String baseUrl) async {
    try {
      // Kita asumsikan ada endpoint '/' di FastAPI
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 2));
      return response.statusCode == 200 || response.statusCode == 404; // Asal server merespons
    } catch (e) {
      return false;
    }
  }

  /// Memindai jaringan lokal secara paralel mencari port 8000
  static Future<String?> scanLocalNetwork() async {
    // Sebagai contoh dasar, kita scan subnet umum 192.168.1.x, 192.168.0.x dan 10.0.2.2 (Emulator)
    final List<String> ipsToScan = ['10.0.2.2'];
    for (int i = 1; i <= 50; i++) { // Membatasi ke 50 IP pertama agar tidak terlalu lama
      ipsToScan.add('192.168.1.$i');
      ipsToScan.add('192.168.0.$i');
    }

    // Lakukan ping paralel (Fire-and-forget)
    final completer = Completer<String?>();
    int pending = ipsToScan.length;

    for (final ip in ipsToScan) {
      final url = 'http://$ip:8000';
      pingServer(url).then((isAlive) {
        if (isAlive && !completer.isCompleted) {
          completer.complete(url);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
    }

    return completer.future;
  }
}
