import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
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
      if (mounted) {
        final l10n = L10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                'Check your email and confirm the address before Superadmin works.',
                'Verifică emailul și confirmă adresa înainte să meargă Superadmin.',
              ),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final l10n = L10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.pick('Registration failed', 'Înregistrarea a eșuat')}: $e',
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

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.of(context).pick(
                'Account creation cancelled',
                'Crearea contului a fost anulată',
              ),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = L10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.pick('Account creation failed', 'Crearea contului a eșuat')}: $e',
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AuthShell(
      showBack: true,
      subtitle: l10n.pick('Create your account', 'Creează-ți contul'),
      cardChild: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              hint: l10n.pick('Full name', 'Nume complet'),
              prefixIcon: Icons.person_outline,
              controller: _nameCtrl,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) {
                  return l10n.pick('Name is required', 'Numele este obligatoriu');
                }
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
                final value = v ?? '';
                if (value.isEmpty) {
                  return l10n.pick('Password is required', 'Parola este obligatorie');
                }
                if (value.length < 6) {
                  return l10n.pick('At least 6 characters', 'Minim 6 caractere');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthGradientButton(
              text: l10n.pick('Create account', 'Creează cont'),
              isLoading: _emailLoading,
              onPressed: _emailLoading ? null : _register,
              gradient: AppColors.greenGradient,
            ),
          ],
        ),
      ),
      belowCard: AuthFooterLink(
        prompt: l10n.pick('Already have an account? ', 'Ai deja un cont? '),
        actionLabel: l10n.pick('Log in', 'Autentificare'),
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
