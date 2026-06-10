// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';

void main() {
  // Keamanan & Stabilitas: Wajib dipanggil sebelum mengeksekusi kode native 
  // (seperti flutter_secure_storage) sebelum runApp berjalan.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TurnBasedGameApp());
}

class TurnBasedGameApp extends StatelessWidget {
  const TurnBasedGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turn Based Game',
      debugShowCheckedModeBanner: false, // Efisiensi UI: Menghilangkan banner debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // Mengerahkan rute awal ke widget pembantu untuk mengecek status sesi
      home: const AuthChecker(),
    );
  }
}

/// Widget AuthChecker berfungsi sebagai gerbang utama (Router/Middleware).
/// Ini mencegah transisi layar yang kasar saat aplikasi pertama kali dibuka.
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _verifySession();
  }

  /// Efisiensi: Membaca token secara lokal dari storage terenkripsi
  /// jauh lebih cepat daripada langsung melakukan request API saat splash screen.
  Future<void> _verifySession() async {
    try {
      final token = await _authService.getToken();
      
      // Verifikasi sederhana: cek apakah token ada dan tidak kosong
      if (token != null && token.isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
        });
      }
    } catch (e) {
      // Keamanan: Jika terjadi error pada secure storage, paksa user ke state unauthenticated
      setState(() {
        _isLoggedIn = false;
      });
    } finally {
      // Hentikan indikator loading setelah pengecekan selesai
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menampilkan layar loading (Splash Screen sederhana) selama pengecekan token
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Navigasi dinamis: Jika token valid, langsung ke Dashboard. Jika tidak, ke Login.
    return _isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }
}