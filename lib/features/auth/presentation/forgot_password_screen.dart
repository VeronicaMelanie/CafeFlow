import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import 'auth_providers.dart';
import 'widgets/auth_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
          backgroundColor: AppColors.softGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      showBack: true,
      subtitle: 'Reset your password',
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your email and we’ll send you a reset link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDark.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AuthTextField(
              hint: 'Email',
              prefixIcon: Icons.email_outlined,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Email is required';
                if (!value.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthGradientButton(
              text: 'Send reset link',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _send,
            ),
          ],
        ),
      ),
      belowCard: AuthFooterLink(
        prompt: 'Remember your password? ',
        actionLabel: 'Back to Login',
        onTap: () => Navigator.pop(context),
      ),
    );
  }
}
