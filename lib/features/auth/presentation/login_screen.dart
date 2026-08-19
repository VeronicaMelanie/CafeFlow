import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import 'auth_providers.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _googleLoading = false;
  bool _emailLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.of(context).pick('Sign-in cancelled', 'Autentificare anulată'),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${L10n.of(context).pick('Sign-in failed', 'Autentificarea a eșuat')}: $e',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _emailLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${L10n.of(context).pick('Sign-in failed', 'Autentificarea a eșuat')}: $e',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AuthShell(
      subtitle: l10n.pick('Welcome back!', 'Bine ai revenit!'),
      cardChild: Form(
        key: _formKey,
        child: Column(
          children: [
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
            const SizedBox(height: 14),
            AuthTextField(
              hint: l10n.pick('Password', 'Parolă'),
              prefixIcon: Icons.lock_outline,
              controller: _passCtrl,
              obscureText: true,
              validator: (v) {
                if ((v ?? '').isEmpty) {
                  return l10n.pick('Password is required', 'Parola este obligatorie');
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryPink,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(
                  l10n.pick('Forgot password?', 'Ai uitat parola?'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AuthGradientButton(
              text: l10n.pick('Log in', 'Autentificare'),
              isLoading: _emailLoading,
              onPressed: _emailLoading ? null : _signInWithEmail,
            ),
          ],
        ),
      ),
      belowCard: AuthFooterLink(
        prompt: l10n.pick("Don't have an account? ", 'Nu ai cont? '),
        actionLabel: l10n.pick('Sign up', 'Creează cont'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          );
        },
      ),
      bottomSection: Column(
        children: [
          const AuthOrDivider(),
          AuthGoogleButton(
            isLoading: _googleLoading,
            onPressed: _googleLoading ? null : _signInWithGoogle,
          ),
        ],
      ),
    );
  }
}
