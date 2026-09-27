import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:steam_app/features/admin/domain/club_config_providers.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/auth/presentation/signup_screen.dart';

void main() {
  group('needsJoinCodeStep', () {
    test('is false while still loading, regardless of anything else', () {
      expect(
        needsJoinCodeStep(resumingFlow: false, joinCodeAccepted: false, joinCodeLoaded: false, configuredCode: 'X'),
        isFalse,
      );
    });

    test('is false once a resuming (already signed-in) flow reaches this screen', () {
      expect(
        needsJoinCodeStep(resumingFlow: true, joinCodeAccepted: false, joinCodeLoaded: true, configuredCode: 'X'),
        isFalse,
      );
    });

    test('is false once this device already accepted the code', () {
      expect(
        needsJoinCodeStep(resumingFlow: false, joinCodeAccepted: true, joinCodeLoaded: true, configuredCode: 'X'),
        isFalse,
      );
    });

    test('is false when the club has not configured a code (open sign-up)', () {
      expect(
        needsJoinCodeStep(resumingFlow: false, joinCodeAccepted: false, joinCodeLoaded: true, configuredCode: null),
        isFalse,
      );
    });

    test('is true only once loaded, not accepted yet, not resuming, and a code is set', () {
      expect(
        needsJoinCodeStep(resumingFlow: false, joinCodeAccepted: false, joinCodeLoaded: true, configuredCode: 'X'),
        isTrue,
      );
    });
  });

  group('SignupScreen join-code gate', () {
    Widget wrap({String? joinCode}) {
      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          joinCodeProvider.overrideWith((ref) => Stream.value(joinCode)),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/signup',
            routes: [
              GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
              GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('Login'))),
            ],
          ),
        ),
      );
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('with no join code configured, sign-up opens straight to the phone/email choice', (tester) async {
      await tester.pumpWidget(wrap(joinCode: null));
      await tester.pump();
      await tester.pump();

      expect(find.text('Club code'), findsNothing);
      expect(find.text('Send verification code'), findsOneWidget);
    });

    testWidgets('with a join code configured, sign-up asks for it first', (tester) async {
      await tester.pumpWidget(wrap(joinCode: 'STEAM2026'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Club code'), findsOneWidget);
      expect(find.text('Send verification code'), findsNothing);
    });

    testWidgets('the wrong code shows an error and does not proceed', (tester) async {
      await tester.pumpWidget(wrap(joinCode: 'STEAM2026'));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextFormField, 'Club code'), 'nope');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("doesn't look right"), findsOneWidget);
      expect(find.text('Club code'), findsOneWidget);
    });

    testWidgets('the right code (case/whitespace-insensitive) reveals the normal sign-up options', (tester) async {
      await tester.pumpWidget(wrap(joinCode: 'STEAM2026'));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextFormField, 'Club code'), '  steam2026  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Club code'), findsNothing);
      expect(find.text('Send verification code'), findsOneWidget);

      // Persisted for next time, per member, on this device.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('joinCodeAccepted'), isTrue);
    });

    testWidgets('a device that already accepted the code is not asked again', (tester) async {
      SharedPreferences.setMockInitialValues({'joinCodeAccepted': true});
      await tester.pumpWidget(wrap(joinCode: 'STEAM2026'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Club code'), findsNothing);
      expect(find.text('Send verification code'), findsOneWidget);
    });
  });
}
