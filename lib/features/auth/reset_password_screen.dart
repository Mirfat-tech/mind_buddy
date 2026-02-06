import 'package:flutter/material.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 💖 ResetPasswordScreen
/// Shown after the user clicks the reset link in their email.
/// Lets them create a new password and updates it via Supabase.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// ✨ Save the new password to Supabase
  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 🔐 Tell Supabase to update the current user's password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text.trim()),
      );

      if (!mounted) return;

      // 🎉 Show success and navigate away
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );

      // After resetting, you can take them to login or home
      context.go('/signin');
    } on AuthException catch (e) {
      // ⚠️ Handle Supabase-specific errors
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update password.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔎 Validators to make sure both passwords match and are strong enough
  String? _validatePassword(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter a new password';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value?.trim() != _password.text.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set a new password'),
        leading: MbGlowBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔑 New password
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'New password'),
                obscureText: true,
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),

              // ✅ Confirm password
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                obscureText: true,
                validator: _validateConfirm,
              ),
              const SizedBox(height: 24),

              // 💕 Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _setNewPassword,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save new password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
