// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../../services/server_config.dart';
import '../../core/constants/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
import 'register_screen.dart';
import '../setup/server_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = 'Username dan password wajib diisi');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final ok = await _auth.login(u, p);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      setState(() => _error = 'Login gagal. Periksa kembali akun Anda.');
    }
  }

  void _toChangeServer() async {
    final storage = const FlutterSecureStorage();
    await storage.delete(key: 'server_url');
    ServerConfig.baseUrl = '';
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ServerSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u2694\ufe0f', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                const Text('Turn Based Arena',
                  style: TextStyle(color: AppColors.gold, fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('Masuk untuk bertarung', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDeco(label: 'Username', icon: Icons.person_rounded),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDeco(
                    label: 'Password',
                    icon: Icons.lock_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error.isNotEmpty) ...
                  [const SizedBox(height: 10),
                  Text(_error, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center)],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Belum punya akun? Daftar sekarang', style: TextStyle(color: AppColors.primary)),
                ),
                TextButton(
                  onPressed: _toChangeServer,
                  child: const Text('Ubah server', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: AppColors.bgCard,
      prefixIcon: Icon(icon, color: Colors.white38),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
