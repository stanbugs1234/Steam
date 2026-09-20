import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/core/utils/friendly_error.dart';
import 'package:steam_app/core/widgets/error_state.dart';

void main() {
  group('friendlyError', () {
    test('sign-in failures read as plain sentences, never raw Firebase text', () {
      final wrong = FirebaseAuthException(code: 'invalid-credential', message: 'The supplied auth credential is incorrect');
      expect(friendlyError(wrong), contains("don't match"));
      expect(friendlyError(wrong), isNot(contains('supplied auth credential')));
      expect(friendlyError(FirebaseAuthException(code: 'email-already-in-use')), contains('already exists'));
      expect(friendlyError(FirebaseAuthException(code: 'too-many-requests')), contains('wait'));
      expect(friendlyError(FirebaseAuthException(code: 'invalid-verification-code')), contains('code'));
    });

    test('offline problems say so', () {
      expect(friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), contains('connection'));
      expect(friendlyError(FirebaseAuthException(code: 'network-request-failed')), contains('connection'));
      expect(friendlyError(const SocketException('x')), contains('connection'));
      expect(friendlyError(TimeoutException('x')), contains('connection'));
    });

    test('permission problems say so without leaking paths', () {
      final denied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions at /users/abc123',
      );
      expect(friendlyError(denied), "You don't have permission to do that.");
    });

    test('anything unknown falls back to the caller\'s sentence', () {
      expect(friendlyError(StateError('boom')), 'Something went wrong. Please try again.');
      expect(friendlyError(StateError('boom'), fallback: 'Custom.'), 'Custom.');
    });
  });

  testWidgets('ErrorState shows a reason and a working Try again button, not the raw error', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorState(
          message: "Couldn't load news right now.",
          error: FirebaseException(plugin: 'cloud_firestore', code: 'unavailable', message: 'RAW-INTERNAL-TEXT'),
          onRetry: () => retried++,
        ),
      ),
    ));

    expect(find.text("Couldn't load news right now."), findsOneWidget);
    expect(find.textContaining('check your connection'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });
}
