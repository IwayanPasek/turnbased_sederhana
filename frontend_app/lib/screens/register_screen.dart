// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  String _errorMessage = '';

  // Efisiensi: Mencegah memory leak dengan membuang controller saat widget ditutup
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Keamanan & Efisiensi: Validasi input di sisi klien sebelum menembak API
    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Semua kolom wajib diisi');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final success = await _authService.register(username, password);

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      // Berikan feedback visual dan kembalikan user ke halaman login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil! Silakan login.')),
      );
      Navigator.pop(context); // Kembali ke halaman sebelumnya (LoginScreen)
    } else {
      setState(() => _errorMessage = 'Registrasi gagal. Username mungkin sudah terpakai.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrasi Akun')),
      body: SingleChildScrollView( // Memastikan layar tidak overflow saat keyboard muncul
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty) ...[
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true, // Keamanan: Sembunyikan karakter
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('DAFTAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}