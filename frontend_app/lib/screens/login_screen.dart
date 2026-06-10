// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  String _errorMessage = '';

  // Efisiensi: Membersihkan controller dari memori saat widget dihancurkan
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validasi input lokal
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Username dan password wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final success = await _authService.login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      // Navigasi ke Dashboard dan hapus history route login (Keamanan UI)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      setState(() => _errorMessage = 'Login gagal. Periksa kembali data Anda.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Game')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              obscureText: true, // Keamanan: Sembunyikan karakter password
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('LOGIN'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Tambahkan baris ini untuk navigasi ke halaman registrasi
            TextButton(
              onPressed: () {
                // Efisiensi: Menggunakan push standar agar bisa kembali (pop) setelah sukses daftar
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text('Belum punya akun? Daftar di sini'),
            ),            
          ],
        ),
      ),
    );
  }
}