// lib/core/utils/jwt_utils.dart
import 'dart:convert';

/// Utilitas decode JWT client-side (tanpa verify signature)
class JwtUtils {
  JwtUtils._();

  /// Decode payload JWT dan kembalikan sebagai Map.
  /// Kembalikan null jika token tidak valid.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Ambil username dari token.
  static String? getUsername(String token) {
    return decodePayload(token)?['username'] as String?;
  }

  /// Cek apakah token sudah expired.
  static bool isExpired(String token) {
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'] as int?;
    if (exp == null) return true;
    return DateTime.now().isAfter(
      DateTime.fromMillisecondsSinceEpoch(exp * 1000),
    );
  }
}
