// lib/services/server_config.dart

class ServerConfig {
  // Efisiensi: Menyimpan URL di memori agar bisa diakses instan oleh seluruh file
  static String baseUrl = '';

  // Keamanan & Logika: Otomatis mengubah protokol HTTP menjadi protokol WebSocket yang sesuai
  // http:// -> ws://
  // https:// -> wss://
  static String get wsUrl {
    if (baseUrl.startsWith('https')) {
      return baseUrl.replaceFirst('https', 'wss');
    } else {
      return baseUrl.replaceFirst('http', 'ws');
    }
  }
}