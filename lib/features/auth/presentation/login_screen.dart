import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;
  String? _errorText;
  bool _showEmailLogin = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      // Router redirect handles navigation based on approval status.
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Could not sign in.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildPhoneLead() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Image.asset('assets/icon/icon.png', height: 96)),
        const SizedBox(height: 16),
        Text('Steam Club', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('Sign in with your phone number', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/signup?mode=phone'),
          child: const Text('Continue with phone'),
        ),
        const SizedBox(height: 8),
        Text(
          "New members: we'll text you a code, then an admin will approve your request.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _showEmailLogin = true),
          child: const Text('Sign in with email instead'),
        ),
      ],
    );
  }

  Widget _buildEmailLogin() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Image.asset('assets/icon/icon.png', height: 96)),
          const SizedBox(height: 16),
          Text('Steam Club', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Sign in to your account', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Forgot password?'),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign In'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/signup?mode=email'),
            child: const Text("Don't have an account? Request one"),
          ),
          TextButton(
            onPressed: () => setState(() => _showEmailLogin = false),
            child: const Text('Sign in with phone instead'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: _showEmailLogin ? _buildEmailLogin() : _buildPhoneLead(),
            ),
          ),
        ),
      ),
    );
  }
}
