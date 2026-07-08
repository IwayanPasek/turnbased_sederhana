// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/setup/server_setup_screen.dart';
import 'services/auth_service.dart';
import 'services/server_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'package:flutter/services.dart';

void main() async {
  // Keamanan: Memastikan native bridge terinisialisasi sebelum mengakses secure storage
  WidgetsFlutterBinding.ensureInitialized();
  
  // Memaksa mode lanskap
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const TurnBasedGameApp());
}

class TurnBasedGameApp extends StatelessWidget {
  const TurnBasedGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turn Based Game',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.bgCard,
        ),
      ),
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  bool _hasServerUrl = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Efisiensi Logika: Melakukan verifikasi berantai (URL Server -> Token JWT)
  /// untuk mencegah kesalahan network request ke alamat yang kosong.
  Future<void> _initializeApp() async {
    try {
      // 1. Periksa apakah URL server sudah pernah disimpan secara lokal
      final savedUrl = await _storage.read(key: 'server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        ServerConfig.baseUrl = savedUrl;
        _hasServerUrl = true;

        // 2. Jika URL valid, lakukan pengecekan token sesi login
        final token = await _authService.getToken();
        if (token != null && token.isNotEmpty) {
          _isLoggedIn = true;
        }
      } else {
        _hasServerUrl = false;
      }
    } catch (e) {
      // Keamanan fallback: Jika storage corrupt, paksa reset status aplikasi
      _hasServerUrl = false;
      _isLoggedIn = false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Alur penentuan layar berdasarkan kelengkapan konfigurasi data
    if (!_hasServerUrl) {
      return const ServerSetupScreen();
    } else if (!_isLoggedIn) {
      return const LoginScreen();
    } else {
      return const MainLayout();
    }
  }
}
