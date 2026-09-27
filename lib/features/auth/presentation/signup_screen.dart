import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/children_form_field.dart';
import '../../../models/app_user.dart';
import '../../../models/child_info.dart';
import '../../admin/domain/club_config_providers.dart';
import '../data/user_repository.dart';
import '../domain/auth_providers.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/legal_links.dart';
import '../../../core/widgets/password_field.dart';

enum _SignupMode { email, phone }

enum _PhoneStep { number, code, completeProfile }

enum _EmailStep { form, verifyEmail, completeProfile }

/// Local, device-only memory of having already entered the right join code —
/// so returning to sign-up (or the app relaunching mid-flow) doesn't ask
/// again. Not tied to an account: nobody is signed in yet when this matters.
const _joinCodeAcceptedPrefsKey = 'joinCodeAccepted';

/// Whether the join-code step should be shown right now. Pulled out as a pure
/// function (mirrors `resolveRedirect` in `router.dart`) so this can't
/// silently regress — e.g. into blocking a resuming sign-up, or into a
/// permanent lockout if `config/app` fails to load.
@visibleForTesting
bool needsJoinCodeStep({
  required bool resumingFlow,
  required bool joinCodeAccepted,
  required bool joinCodeLoaded,
  required String? configuredCode,
}) {
  // Already past this step earlier in the same flow — never re-ask, and
  // never let a cleared local flag or a slow config read strand someone
  // who's already signed in and mid-signup.
  if (resumingFlow || joinCodeAccepted || !joinCodeLoaded) return false;
  // No code configured: the club hasn't turned this on, so sign-up is open.
  return configuredCode != null;
}

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

  // Shared between the phone and email "complete profile" steps (and,
  // likewise, _nameCtrl/_phoneCtrl below are reused by both) — only one flow
  // is ever active in a given session.
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

  // Email flow: Step 1 email+password, Step 2 "check your email", Step 3
  // (new users only) complete profile — mirrors the phone flow above.
  _EmailStep _emailStep = _EmailStep.form;
  User? _verifiedEmailUser;
  bool _checkingVerification = false;
  bool _completingEmailProfile = false;

  // Club join code: a device-remembered, one-time gate shown before either
  // sign-up path. `null` while still loading the stored flag.
  bool? _joinCodeAccepted;
  final _joinCodeFormKey = GlobalKey<FormState>();
  final _joinCodeCtrl = TextEditingController();
  bool _checkingJoinCode = false;

  @override
  void initState() {
    super.initState();
    // The router sends anyone who is signed in but has no profile yet back
    // here (a fresh signup, or one interrupted part-way). Pick up at the
    // right step rather than asking them to start over.
    final signedIn = ref.read(authStateProvider).valueOrNull;
    if (signedIn != null) {
      final isEmailAccount = signedIn.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID);
      if (isEmailAccount) {
        _mode = _SignupMode.email;
        _verifiedEmailUser = signedIn;
        _emailStep = signedIn.emailVerified ? _EmailStep.completeProfile : _EmailStep.verifyEmail;
        // The cached flag can be stale if verification happened outside the
        // app (e.g. tapping the email link in a browser); refresh it once
        // mounted rather than blocking initState on a network call.
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEmailVerification());
      } else {
        _mode = _SignupMode.phone;
        _verifiedPhoneUser = signedIn;
        _e164Phone = signedIn.phoneNumber;
        _phoneStep = _PhoneStep.completeProfile;
      }
    }
    _loadJoinCodeAccepted();
  }

  Future<void> _loadJoinCodeAccepted() async {
    bool accepted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      accepted = prefs.getBool(_joinCodeAcceptedPrefsKey) ?? false;
    } catch (_) {
      // Storage unavailable: fall through and ask for the code.
    }
    if (mounted) setState(() => _joinCodeAccepted = accepted);
  }

  Future<void> _refreshEmailVerification() async {
    final user = _verifiedEmailUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.reload();
    } catch (_) {
      return;
    }
    if (mounted && user.emailVerified && _emailStep == _EmailStep.verifyEmail) {
      setState(() => _emailStep = _EmailStep.completeProfile);
    }
  }

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
    _joinCodeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Step 1 of the email path: create the account and send a verification
  /// link. Name/phone/kids are collected later, once verified (see
  /// `_buildEmailCompleteProfileStep`) — collecting them here instead would
  /// lose them if the app is closed while waiting on the email.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final email = _emailCtrl.text.trim();
      final credential = await authRepo.signUp(email: email, password: _passwordCtrl.text);
      final user = credential.user!;
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Non-fatal — they can use Resend on the next screen.
      }
      if (!mounted) return;
      setState(() {
        _verifiedEmailUser = user;
        _emailStep = _EmailStep.verifyEmail;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = friendlyError(e, fallback: 'Could not create your account. Please try again.'));
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = _verifiedEmailUser;
    if (user == null) return;
    setState(() => _errorText = null);
    try {
      await user.sendEmailVerification();
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = _messageForAuthError(e));
    } catch (_) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    }
  }

  /// "Continue" on the verify-email step: re-checks with Firebase whether the
  /// link has been tapped yet.
  Future<void> _checkEmailVerified() async {
    final user = _verifiedEmailUser;
    if (user == null) return;
    setState(() {
      _checkingVerification = true;
      _errorText = null;
    });
    try {
      await user.reload();
      if (!user.emailVerified) {
        setState(() => _errorText = 'Not verified yet — check your email (and spam folder), then try again.');
        return;
      }
      if (!mounted) return;
      setState(() => _emailStep = _EmailStep.completeProfile);
    } catch (_) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _checkingVerification = false);
    }
  }

  /// Step 3 of the email path, once verified: mirrors `_finishPhoneProfile`
  /// exactly, using a verified email in place of a verified phone number.
  Future<void> _finishEmailProfile() async {
    if (!(_completeProfileFormKey.currentState?.validate() ?? false)) return;
    final firebaseUser = _verifiedEmailUser;
    if (firebaseUser == null) return;

    setState(() {
      _completingEmailProfile = true;
      _errorText = null;
    });

    final userRepo = ref.read(userRepositoryProvider);
    try {
      final email = firebaseUser.email ?? '';
      AppUser? placeholder;
      try {
        placeholder = email.isEmpty ? null : await userRepo.findApprovedPlaceholderByEmail(email);
      } catch (_) {
        // If the lookup fails for any reason, fall through to a normal
        // pending signup rather than blocking the user from signing up.
        placeholder = null;
      }

      final merged = AppUser(
        uid: firebaseUser.uid,
        name: _nameCtrl.text.trim(),
        email: email,
        phone: _phoneCtrl.text.trim(),
        kids: _kids.isNotEmpty ? _kids : (placeholder?.kids ?? const []),
        role: UserRole.member,
        status: placeholder != null ? UserStatus.approved : UserStatus.pending,
        mergedFromId: placeholder?.uid,
        createdAt: placeholder?.createdAt,
        memberNumber: placeholder?.memberNumber,
        clubPoints: placeholder?.clubPoints,
        yearlyPoints: placeholder?.yearlyPoints,
        duesPaid: placeholder?.duesPaid ?? false,
        isNewMember: placeholder?.isNewMember ?? false,
      );

      if (placeholder != null) {
        await userRepo.createProfileClaiming(merged, placeholder.uid);
      } else {
        await userRepo.createProfile(merged);
      }
      // Router redirect will move to /pending-approval (or straight to /home
      // if merged as approved) automatically.
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _completingEmailProfile = false);
    }
  }

  Future<void> _checkJoinCode() async {
    if (!(_joinCodeFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _checkingJoinCode = true;
      _errorText = null;
    });
    try {
      final configured = await ref.read(joinCodeProvider.future);
      final entered = _joinCodeCtrl.text.trim().toLowerCase();
      if (configured == null || entered != configured.trim().toLowerCase()) {
        setState(() => _errorText = "That code doesn't look right. Check with the club and try again.");
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_joinCodeAcceptedPrefsKey, true);
      } catch (_) {
        // Best-effort — they'll just be asked again next time.
      }
      if (mounted) setState(() => _joinCodeAccepted = true);
    } catch (_) {
      setState(() => _errorText = "Couldn't check that right now. Please try again.");
    } finally {
      if (mounted) setState(() => _checkingJoinCode = false);
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
        return friendlyError(e);
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
      final phone = _e164Phone ?? firebaseUser.phoneNumber ?? '';
      AppUser? placeholder;
      try {
        placeholder = phone.isEmpty ? null : await userRepo.findApprovedPlaceholderByPhone(phone);
      } catch (_) {
        // If the lookup fails for any reason, fall through to a normal
        // pending signup rather than blocking the user from signing up.
        placeholder = null;
      }

      final merged = AppUser(
        uid: firebaseUser.uid,
        name: _phoneNameCtrl.text.trim(),
        email: firebaseUser.email ?? placeholder?.email ?? '',
        phone: phone,
        kids: _kids.isNotEmpty ? _kids : (placeholder?.kids ?? const []),
        role: UserRole.member,
        status: placeholder != null ? UserStatus.approved : UserStatus.pending,
        mergedFromId: placeholder?.uid,
        // Preserve the placeholder's original join date on merge — otherwise
        // toFirestore() would stamp today's date and lose their real tenure.
        createdAt: placeholder?.createdAt,
        // ...and the roster's own records, which would otherwise vanish along
        // with the placeholder we delete right after.
        memberNumber: placeholder?.memberNumber,
        clubPoints: placeholder?.clubPoints,
        yearlyPoints: placeholder?.yearlyPoints,
        duesPaid: placeholder?.duesPaid ?? false,
        isNewMember: placeholder?.isNewMember ?? false,
      );

      if (placeholder != null) {
        await userRepo.createProfileClaiming(merged, placeholder.uid);
      } else {
        await userRepo.createProfile(merged);
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
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _passwordCtrl,
            isNewPassword: true,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirmCtrl,
            label: 'Confirm password',
            isNewPassword: true,
            textInputAction: TextInputAction.done,
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
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We sent a verification link to ${_verifiedEmailUser?.email ?? _emailCtrl.text.trim()}. '
          'Tap the link, then come back and press Continue.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _checkingVerification ? null : _checkEmailVerified,
          child: _checkingVerification
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _resendCooldownSeconds > 0 ? null : _resendVerificationEmail,
          child: Text(_resendCooldownSeconds > 0 ? 'Resend email (${_resendCooldownSeconds}s)' : 'Resend email'),
        ),
        TextButton(
          onPressed: _checkingVerification ? null : () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Use a different account'),
        ),
      ],
    );
  }

  Widget _buildEmailCompleteProfileStep() {
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
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Your full name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _completingEmailProfile ? null : _finishEmailProfile,
            child: _completingEmailProfile
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Finish'),
          ),
          TextButton(
            onPressed: _completingEmailProfile ? null : () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCodeStep() {
    return Form(
      key: _joinCodeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _joinCodeCtrl,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Club code'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            onFieldSubmitted: (_) => _checkingJoinCode ? null : _checkJoinCode(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _checkingJoinCode ? null : _checkJoinCode,
            child: _checkingJoinCode
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue'),
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
          TextButton(
            onPressed: _completingProfile ? null : () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegistering = _mode == _SignupMode.email || _phoneStep == _PhoneStep.completeProfile;

    // Once already signed in and resuming mid-flow, the join code was
    // necessarily passed already — never re-ask (it could even strand a
    // returning member if local storage was cleared since).
    final resumingFlow = _verifiedPhoneUser != null || _verifiedEmailUser != null;
    final joinCodeAsync = ref.watch(joinCodeProvider);
    // `hasError` counts as "loaded" too: a config read that never resolves
    // must not block sign-up forever — see needsJoinCodeStep's doc comment.
    final joinCodeLoaded = _joinCodeAccepted != null && (joinCodeAsync.hasValue || joinCodeAsync.hasError);
    final joinCodeStillLoading = !resumingFlow && !joinCodeLoaded;
    // Fails open on a loading/error config read — the real gate remains
    // admin approval, so a transient read problem shouldn't block sign-up.
    final needsJoinCode = needsJoinCodeStep(
      resumingFlow: resumingFlow,
      joinCodeAccepted: _joinCodeAccepted ?? false,
      joinCodeLoaded: joinCodeLoaded,
      configuredCode: joinCodeAsync.valueOrNull,
    );
    final showingVerifyEmail = _mode == _SignupMode.email && _emailStep == _EmailStep.verifyEmail;

    String title;
    String subtitle;
    if (!resumingFlow && joinCodeStillLoading) {
      title = 'Join STEAM Club';
      subtitle = '';
    } else if (needsJoinCode) {
      title = 'Enter your club code';
      subtitle = "Ask the club if you don't have one.";
    } else if (showingVerifyEmail) {
      title = 'Verify your email';
      subtitle = 'Check your inbox for a link from us.';
    } else {
      title = isRegistering ? 'Join STEAM Club' : 'Sign in with your phone number';
      subtitle = isRegistering ? 'An admin will review and approve your request.' : "We'll text you a one-time code.";
    }

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
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  if (!resumingFlow && joinCodeStillLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (needsJoinCode)
                    _buildJoinCodeStep()
                  else if (showingVerifyEmail)
                    _buildVerifyEmailStep()
                  else ...[
                    if (_mode == _SignupMode.email || _phoneStep == _PhoneStep.number) ...[
                      _buildModeToggle(),
                      const SizedBox(height: 20),
                    ],
                    if (_mode == _SignupMode.email)
                      (_emailStep == _EmailStep.completeProfile ? _buildEmailCompleteProfileStep() : _buildEmailForm())
                    else if (_phoneStep == _PhoneStep.completeProfile)
                      _buildCompleteProfileStep()
                    else if (_phoneStep == _PhoneStep.code)
                      _buildCodeEntryStep()
                    else
                      _buildPhoneNumberStep(),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                  const SizedBox(height: 12),
                  LegalLinks(
                    prefix: isRegistering
                        ? 'By requesting an account, you agree to the'
                        : 'By continuing, you agree to the',
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
