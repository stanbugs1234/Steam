import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/children_form_field.dart';
import '../../../models/app_user.dart';
import '../../../models/child_info.dart';
import '../data/user_repository.dart';
import '../domain/auth_providers.dart';

enum _SignupMode { email, phone }

enum _PhoneStep { number, code, completeProfile }

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Shared between the email form and the phone "complete profile" step —
  // only one of those is ever active in a given session.
  List<ChildInfo> _kids = [];

  bool _submitting = false;
  String? _errorText;

  _SignupMode _mode = _SignupMode.phone;
  bool _modeInitializedFromQuery = false;

  // Phone flow: Step 1 number entry, Step 2 code entry, Step 3 (new users
  // only) complete profile.
  final _phoneFormKey = GlobalKey<FormState>();
  final _completeProfileFormKey = GlobalKey<FormState>();
  final _phoneNameCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  String? _e164Phone;
  _PhoneStep _phoneStep = _PhoneStep.number;
  User? _verifiedPhoneUser;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _completingProfile = false;
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_modeInitializedFromQuery) {
      _modeInitializedFromQuery = true;
      final queryMode = GoRouterState.of(context).uri.queryParameters['mode'];
      if (queryMode == 'email') {
        setState(() => _mode = _SignupMode.email);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneNameCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _smsCodeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);

      final email = _emailCtrl.text.trim();
      final credential = await authRepo.signUp(
        email: email,
        password: _passwordCtrl.text,
      );
      final uid = credential.user!.uid;

      AppUser? placeholder;
      try {
        placeholder = await userRepo.findApprovedPlaceholderByEmail(email);
      } catch (_) {
        // If the lookup fails for any reason, fall through to a normal
        // pending signup rather than blocking account creation.
        placeholder = null;
      }

      final phone = _phoneCtrl.text.trim();
      await userRepo.createProfile(AppUser(
        uid: uid,
        name: _nameCtrl.text.trim(),
        email: email,
        phone: phone.isNotEmpty ? phone : (placeholder?.phone ?? ''),
        kids: _kids.isNotEmpty ? _kids : (placeholder?.kids ?? const []),
        role: UserRole.member,
        status: placeholder != null ? UserStatus.approved : UserStatus.pending,
        mergedFromId: placeholder?.uid,
        // Preserve the placeholder's original join date on merge — otherwise
        // toFirestore() would stamp today's date and lose their real tenure.
        createdAt: placeholder?.createdAt,
      ));

      if (placeholder != null) {
        try {
          await userRepo.deletePlaceholder(placeholder.uid);
        } catch (_) {
          // Non-fatal: the real account was already created successfully;
          // a leftover placeholder just needs manual cleanup by an admin.
        }
      }
      // Router redirect will move to /pending-approval (or straight to
      // /home if merged as approved) automatically.
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Could not create account.');
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return "That doesn't look like a valid phone number.";
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return "That code isn't right. Check and try again.";
      case 'session-expired':
      case 'code-expired':
        return 'This code expired — request a new one.';
      case 'web-context-cancelled':
        return 'Verification was cancelled. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldownSeconds--;
        if (_resendCooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  /// Called right after a phone number is verified (whether that's a brand
  /// new sign-up or a returning member signing back in). Deliberately no
  /// try/catch around the final `getUser` lookup beyond the permission-denied
  /// retry below: if it still fails, let the error surface via the caller's
  /// own catch block rather than silently treating a lookup failure as "new
  /// user" and risking a profile overwrite.
  Future<void> _afterPhoneVerified(User firebaseUser) async {
    final userRepo = ref.read(userRepositoryProvider);
    final existing = await _getUserRetryingPermissionDenied(userRepo, firebaseUser.uid);
    if (existing != null) {
      // Returning member — leave their profile untouched and let the router
      // redirect take them to /home (or /pending-approval / /denied).
      return;
    }
    if (!mounted) return;
    setState(() {
      _verifiedPhoneUser = firebaseUser;
      _phoneStep = _PhoneStep.completeProfile;
    });
  }

  Future<void> _finishPhoneProfile() async {
    if (!(_completeProfileFormKey.currentState?.validate() ?? false)) return;
    final firebaseUser = _verifiedPhoneUser;
    if (firebaseUser == null) return;

    setState(() {
      _completingProfile = true;
      _errorText = null;
    });

    final userRepo = ref.read(userRepositoryProvider);
    try {
      AppUser? placeholder;
      try {
        placeholder = await userRepo.findApprovedPlaceholderByPhone(_e164Phone ?? '');
      } catch (_) {
        // If the lookup fails for any reason, fall through to a normal
        // pending signup rather than blocking the user from signing up.
        placeholder = null;
      }

      final merged = AppUser(
        uid: firebaseUser.uid,
        name: _phoneNameCtrl.text.trim(),
        email: placeholder?.email ?? '',
        phone: _e164Phone ?? '',
        kids: _kids.isNotEmpty ? _kids : (placeholder?.kids ?? const []),
        role: UserRole.member,
        status: placeholder != null ? UserStatus.approved : UserStatus.pending,
        mergedFromId: placeholder?.uid,
        // Preserve the placeholder's original join date on merge — otherwise
        // toFirestore() would stamp today's date and lose their real tenure.
        createdAt: placeholder?.createdAt,
      );

      await userRepo.createProfile(merged);

      if (placeholder != null) {
        try {
          await userRepo.deletePlaceholder(placeholder.uid);
        } catch (_) {
          // Non-fatal: the real account was already created successfully;
          // a leftover placeholder just needs manual cleanup by an admin.
        }
      }
      // Router redirect will move to /pending-approval (or straight to /home
      // if merged as approved) automatically.
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _completingProfile = false);
    }
  }

  Future<void> _sendCode({int? forceResendingToken}) async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sendingCode = true;
      _errorText = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    _e164Phone = '+1${_phoneNumberCtrl.text.trim()}';

    try {
      await authRepo.verifyPhoneNumber(
        phoneNumber: _e164Phone!,
        forceResendingToken: forceResendingToken,
        onAutoVerified: (credential) async {
          try {
            final userCredential = await authRepo.signInWithPhoneCredential(credential);
            await _afterPhoneVerified(userCredential.user!);
          } on FirebaseAuthException catch (e) {
            if (mounted) setState(() => _errorText = _messageForAuthError(e));
          } finally {
            if (mounted) setState(() => _sendingCode = false);
          }
        },
        onFailed: (e) {
          if (mounted) {
            setState(() {
              _errorText = _messageForAuthError(e);
              _sendingCode = false;
            });
          }
        },
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _phoneStep = _PhoneStep.code;
            _sendingCode = false;
          });
          _startResendCooldown();
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Something went wrong. Please try again.';
          _sendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null || _smsCodeCtrl.text.trim().length < 6) return;
    setState(() {
      _verifyingCode = true;
      _errorText = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userCredential = await authRepo.signInWithSmsCode(
        verificationId: _verificationId!,
        smsCode: _smsCodeCtrl.text.trim(),
      );
      await _afterPhoneVerified(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = _messageForAuthError(e));
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  void _changePhoneNumber() {
    _cooldownTimer?.cancel();
    setState(() {
      _phoneStep = _PhoneStep.number;
      _verificationId = null;
      _resendToken = null;
      _errorText = null;
      _smsCodeCtrl.clear();
      _resendCooldownSeconds = 0;
    });
  }

  Widget _buildModeToggle() {
    return SegmentedButton<_SignupMode>(
      segments: const [
        ButtonSegment(value: _SignupMode.phone, label: Text('Phone')),
        ButtonSegment(value: _SignupMode.email, label: Text('Email')),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) {
        setState(() {
          _mode = selection.first;
          _errorText = null;
        });
      },
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your full name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          ChildrenFormField(initialChildren: _kids, onChanged: (kids) => _kids = kids),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) => (v != _passwordCtrl.text) ? 'Passwords do not match' : null,
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Request Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumberStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // US-only for now: a fixed +1 prefix keeps this simple for a single
          // school club. Add a country picker here if that ever changes.
          TextFormField(
            controller: _phoneNumberCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(labelText: 'Phone number', prefixText: '+1 '),
            validator: (v) =>
                (v == null || v.trim().length != 10) ? 'Enter a valid 10-digit phone number' : null,
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sendingCode ? null : () => _sendCode(),
            child: _sendingCode
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send verification code'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEntryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the code we texted to +1 ${_phoneNumberCtrl.text.trim()}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _smsCodeCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _verifyingCode ? null : _verifyCode,
          child: _verifyingCode
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _resendCooldownSeconds > 0 ? null : () => _sendCode(forceResendingToken: _resendToken),
          child: Text(_resendCooldownSeconds > 0 ? 'Resend code (${_resendCooldownSeconds}s)' : 'Resend code'),
        ),
        TextButton(
          onPressed: _changePhoneNumber,
          child: const Text('Change phone number'),
        ),
      ],
    );
  }

  Widget _buildCompleteProfileStep() {
    return Form(
      key: _completeProfileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "You're verified — just need a couple more details.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your full name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          ChildrenFormField(initialChildren: _kids, onChanged: (kids) => _kids = kids),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _completingProfile ? null : _finishPhoneProfile,
            child: _completingProfile
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegistering = _mode == _SignupMode.email || _phoneStep == _PhoneStep.completeProfile;

    return Scaffold(
      appBar: AppBar(title: Text(isRegistering ? 'Request an Account' : 'Sign in')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/icon/icon.png', height: 72)),
                  const SizedBox(height: 12),
                  Text(
                    isRegistering ? 'Join the Steam Club' : 'Sign in with your phone number',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRegistering
                        ? 'An admin will review and approve your request.'
                        : "We'll text you a one-time code.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_mode == _SignupMode.email || _phoneStep == _PhoneStep.number) ...[
                    _buildModeToggle(),
                    const SizedBox(height: 20),
                  ],
                  if (_mode == _SignupMode.email)
                    _buildEmailForm()
                  else if (_phoneStep == _PhoneStep.completeProfile)
                    _buildCompleteProfileStep()
                  else if (_phoneStep == _PhoneStep.code)
                    _buildCodeEntryStep()
                  else
                    _buildPhoneNumberStep(),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Firestore's client can briefly lag a beat behind a just-completed sign-in
/// before it picks up the fresh auth token, which spuriously denies the very
/// next read with `permission-denied` even though the user is legitimately
/// signed in. Retry a couple of times with a short backoff before giving up.
Future<AppUser?> _getUserRetryingPermissionDenied(UserRepository userRepo, String uid) async {
  const maxAttempts = 3;
  for (var attempt = 1; ; attempt++) {
    try {
      return await userRepo.getUser(uid);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' || attempt >= maxAttempts) rethrow;
      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
  }
}
