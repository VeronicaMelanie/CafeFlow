import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
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
          const SnackBar(
            content: Text('Sign-in cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: $e'),
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
            content: Text('Sign-in failed: $e'),
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
    return AuthShell(
      subtitle: 'Welcome back, Staff!',
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
                if (value.isEmpty) return 'Email is required';
                if (!value.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              hint: 'Password',
              prefixIcon: Icons.lock_outline,
              controller: _passCtrl,
              obscureText: true,
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Password is required';
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
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AuthGradientButton(
              text: 'Login',
              isLoading: _emailLoading,
              onPressed: _emailLoading ? null : _signInWithEmail,
            ),
          ],
        ),
      ),
      belowCard: AuthFooterLink(
        prompt: "Don't have an account? ",
        actionLabel: 'Sign Up',
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
