import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../core/constants/app_colors.dart';

class GiveSpecificItemDialog extends StatefulWidget {
  final int userId;
  final String username;
  final AdminService adminService;
  final VoidCallback onSuccess;

  const GiveSpecificItemDialog({
    super.key,
    required this.userId,
    required this.username,
    required this.adminService,
    required this.onSuccess,
  });

  @override
  State<GiveSpecificItemDialog> createState() => _GiveSpecificItemDialogState();
}

class _GiveSpecificItemDialogState extends State<GiveSpecificItemDialog> {
  int _itemId = 1;
  int _level = 1;
  int _amount = 1;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_itemId <= 0 || _level <= 0 || _amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Item, Level, dan Jumlah harus valid (>0)'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await widget.adminService.giveItem(widget.userId, _itemId, _level, _amount);
      if (res != null && res['success'] == true) {
        widget.onSuccess();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Berhasil memberikan item')),
          );
        }
      } else {
        throw Exception(res?['detail'] ?? 'Gagal memberi item');
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
      title: Text('Beri Item ke ${widget.username}', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Item ID (Lihat di DB shop_items)',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
            onChanged: (val) => _itemId = int.tryParse(val) ?? 0,
          ),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Level',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
            onChanged: (val) => _level = int.tryParse(val) ?? 1,
          ),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
            onChanged: (val) => _amount = int.tryParse(val) ?? 1,
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
              : const Text('Berikan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showGiveSpecificItemDialog(
  BuildContext context,
  int userId,
  String username,
  AdminService adminService,
  VoidCallback onSuccess,
) {
  showDialog(
    context: context,
    builder: (context) => GiveSpecificItemDialog(
      userId: userId,
      username: username,
      adminService: adminService,
      onSuccess: onSuccess,
    ),
  );
}
