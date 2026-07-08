// lib/screens/setup/server_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/server_config.dart';
import '../../services/server_discovery_service.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});
  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _urlCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  
  bool _loading = false;
  bool _discovering = true; // Auto-discovery saat pertama kali dibuka
  String _error = '';
  String _statusText = 'Mencari server otomatis...';

  @override
  void initState() {
    super.initState();
    _startAutoDiscovery();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _startAutoDiscovery() async {
    setState(() {
      _discovering = true;
      _statusText = 'Mengecek Central Registry...';
      _error = '';
    });

    // 1. Cek dari Cloud Registry
    String? foundUrl = await ServerDiscoveryService.fetchFromRegistry();
    
    if (!mounted) return;

    if (foundUrl != null) {
      setState(() => _statusText = 'Server ditemukan! Mengalihkan...');
      _urlCtrl.text = foundUrl;
      await Future.delayed(const Duration(milliseconds: 800));
      _saveUrlAndProceed(foundUrl);
      return;
    }

    // 2. Jika Cloud gagal, biarkan user memilih scan Wi-Fi atau manual
    setState(() {
      _discovering = false;
      _statusText = 'Server otomatis tidak ditemukan.';
    });
  }

  Future<void> _scanLAN() async {
    setState(() {
      _loading = true;
      _error = '';
      _statusText = 'Memindai Wi-Fi Lokal...';
    });

    String? lanUrl = await ServerDiscoveryService.scanLocalNetwork();

    if (!mounted) return;
    setState(() => _loading = false);

    if (lanUrl != null) {
      _urlCtrl.text = lanUrl;
      setState(() => _statusText = 'Server lokal ditemukan: $lanUrl');
      // Anda bisa otomatis lanjut atau membiarkan user klik Simpan
    } else {
      setState(() {
        _error = 'Tidak ada server yang merespons di jaringan ini.';
        _statusText = '';
      });
    }
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) { setState(() => _error = 'URL tidak boleh kosong'); return; }
    if (!url.startsWith('http')) { setState(() => _error = 'URL harus diawali http:// atau https://'); return; }
    
    setState(() { _loading = true; _error = ''; _statusText = 'Memverifikasi koneksi...'; });
    
    bool isAlive = await ServerDiscoveryService.pingServer(url);
    if (!isAlive) {
      setState(() {
        _loading = false;
        _error = 'Gagal terhubung ke $url';
        _statusText = '';
      });
      return;
    }

    _saveUrlAndProceed(url);
  }

  Future<void> _saveUrlAndProceed(String url) async {
    ServerConfig.baseUrl = url;
    await _storage.write(key: 'server_url', value: url);
    
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{1F310}', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text('Menghubungkan ke Server', style: TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                
                if (_discovering) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  const SizedBox(height: 16),
                  Center(child: Text(_statusText, style: const TextStyle(color: Colors.white70))),
                ] else ...[
                  const Text('Pilih cara untuk terhubung ke game server.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 24),
                  
                  // Tombol Scan LAN
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _scanLAN,
                      icon: const Icon(Icons.wifi, color: Colors.white),
                      label: Text(_loading ? _statusText : 'Scan Jaringan Lokal (Wi-Fi)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white24)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("ATAU MANUAL", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                  ),
                  
                  TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'https://xxxx.ngrok.app',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      prefixIcon: const Icon(Icons.link, color: Colors.white38),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[const SizedBox(height: 8), Text(_error, style: const TextStyle(color: AppColors.danger))],
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading 
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan & Lanjutkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
