import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../core/constants/app_colors.dart';

class ResetPasswordDialog extends StatefulWidget {
  final int userId;
  final String username;
  final AdminService adminService;

  const ResetPasswordDialog({
    super.key,
    required this.userId,
    required this.username,
    required this.adminService,
  });

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  String _newPassword = '';
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);

    try {
      final res = await widget.adminService.resetPassword(widget.userId, _newPassword);
      if (res != null && res['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Kata sandi berhasil direset')),
          );
        }
      } else {
        throw Exception(res?['detail'] ?? 'Gagal mereset kata sandi');
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
      title: Text('Reset Password ${widget.username}', style: const TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          style: const TextStyle(color: Colors.white),
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Kata Sandi Baru',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
          validator: (val) {
            if (val == null || val.length < 4) {
              return 'Minimal terdiri dari 4 karakter';
            }
            return null;
          },
          onChanged: (val) => _newPassword = val,
        ),
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
              : const Text('Reset', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showResetPasswordDialog(BuildContext context, int userId, String username, AdminService adminService) {
  showDialog(
    context: context,
    builder: (context) => ResetPasswordDialog(
      userId: userId,
      username: username,
      adminService: adminService,
    ),
  );
}
