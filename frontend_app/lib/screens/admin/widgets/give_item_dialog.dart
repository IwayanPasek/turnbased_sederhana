import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../core/constants/app_colors.dart';

class GiveCurrencyDialog extends StatefulWidget {
  final int userId;
  final String username;
  final AdminService adminService;
  final VoidCallback onSuccess;

  const GiveCurrencyDialog({
    super.key,
    required this.userId,
    required this.username,
    required this.adminService,
    required this.onSuccess,
  });

  @override
  State<GiveCurrencyDialog> createState() => _GiveCurrencyDialogState();
}

class _GiveCurrencyDialogState extends State<GiveCurrencyDialog> {
  int _coins = 0;
  int _gems = 0;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_coins < 0 || _gems < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nilai koin/gems tidak boleh negatif'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await widget.adminService.giveCurrency(widget.userId, _coins, _gems);
      if (res != null && res['success'] == true) {
        widget.onSuccess();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Berhasil memberikan mata uang')),
          );
        }
      } else {
        throw Exception(res?['detail'] ?? 'Gagal memberi mata uang');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgDark,
      title: Text('Beri Mata Uang ke ${widget.username}', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Koin',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
            onChanged: (val) => _coins = int.tryParse(val) ?? 0,
          ),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Gems',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
            onChanged: (val) => _gems = int.tryParse(val) ?? 0,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Kirim', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showGiveCurrencyDialog(BuildContext context, int userId, String username, AdminService adminService, VoidCallback onSuccess) {
  showDialog(
    context: context,
    builder: (context) => GiveCurrencyDialog(
      userId: userId,
      username: username,
      adminService: adminService,
      onSuccess: onSuccess,
    ),
  );
}
