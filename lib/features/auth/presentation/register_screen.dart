import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import 'auth_providers.dart';
import 'widgets/auth_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _emailLoading = false;
  bool _googleLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _emailLoading = true);
    try {
      await ref.read(authRepositoryProvider).signUpWithEmail(
            _emailCtrl.text.trim(),
            _passCtrl.text,
            _nameCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-up cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-up failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      showBack: true,
      subtitle: 'Create your account',
      cardChild: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              hint: 'Full name',
              prefixIcon: Icons.person_outline,
              controller: _nameCtrl,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),
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
                final value = v ?? '';
                if (value.isEmpty) return 'Password is required';
                if (value.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthGradientButton(
              text: 'Sign Up',
              isLoading: _emailLoading,
              onPressed: _emailLoading ? null : _register,
              gradient: AppColors.greenGradient,
            ),
          ],
        ),
      ),
      belowCard: AuthFooterLink(
        prompt: 'Already have an account? ',
        actionLabel: 'Login',
        onTap: () => Navigator.pop(context),
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
