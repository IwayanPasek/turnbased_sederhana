// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    final c = _confirmCtrl.text;
    if (u.isEmpty || p.isEmpty) { setState(() => _error = 'Semua field wajib diisi'); return; }
    if (p != c) { setState(() => _error = 'Password tidak cocok'); return; }
    if (p.length < 6) { setState(() => _error = 'Password minimal 6 karakter'); return; }
    setState(() { _loading = true; _error = ''; });
    final ok = await _auth.register(u, p);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil! Silakan login.'), backgroundColor: AppColors.accent),
      );
    } else {
      setState(() => _error = 'Registrasi gagal. Username mungkin sudah digunakan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Daftar Akun', style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F6E1}\ufe0f', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 8),
                const Text('Buat Akun Baru', style: TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 28),
                _field(_usernameCtrl, 'Username', Icons.person_rounded),
                const SizedBox(height: 12),
                _field(_passwordCtrl, 'Password', Icons.lock_rounded, obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),
                const SizedBox(height: 12),
                _field(_confirmCtrl, 'Konfirmasi Password', Icons.lock_outline_rounded, obscure: true),
                if (_error.isNotEmpty) ...[const SizedBox(height: 10),
                  Text(_error, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center)],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Daftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
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
      ),
    );
  }
}
