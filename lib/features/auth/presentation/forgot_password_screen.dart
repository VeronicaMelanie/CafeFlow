import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
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
        SnackBar(
          content: Text(
            L10n.of(context).pick(
              'Password reset email sent.',
              'Emailul de resetare a parolei a fost trimis.',
            ),
          ),
          backgroundColor: AppColors.softGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${L10n.of(context).pick('Failed', 'A eșuat')}: $e',
            ),
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
    final l10n = L10n.of(context);
    return AuthShell(
      showBack: true,
      subtitle: l10n.pick('Reset your password', 'Resetează-ți parola'),
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.pick(
                'Enter your email and we\'ll send you a reset link.',
                'Introdu emailul și îți vom trimite un link de resetare.',
              ),
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
                if (value.isEmpty) {
                  return l10n.pick('Email is required', 'Emailul este obligatoriu');
                }
                if (!value.contains('@')) {
                  return l10n.pick('Invalid email', 'Email invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthGradientButton(
              text: l10n.pick('Send reset link', 'Trimite linkul de resetare'),
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _send,
            ),
          ],
        ),
      ),
      belowCard: AuthFooterLink(
        prompt: l10n.pick('Remember your password? ', 'Îți amintești parola? '),
        actionLabel: l10n.pick('Back to log in', 'Înapoi la autentificare'),
        onTap: () => Navigator.pop(context),
      ),
    );
  }
}
