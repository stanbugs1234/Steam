import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:steam_app/features/auth/presentation/login_screen.dart';

Future<void> _pumpLogin(WidgetTester tester) {
  return tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
}

void main() {
  testWidgets('Login screen opens on the email sign-in form', (WidgetTester tester) async {
    await _pumpLogin(tester);

    expect(find.text('STEAM Club'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in with phone instead'), findsOneWidget);
  });

  testWidgets('Login screen can switch to phone sign-in and back', (WidgetTester tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.text('Sign in with phone instead'));
    await tester.pump();
    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Sign in with email instead'), findsOneWidget);

    await tester.tap(find.text('Sign in with email instead'));
    await tester.pump();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Login screen links to the Terms of Use and Privacy Policy', (WidgetTester tester) async {
    await _pumpLogin(tester);

    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('Password can be shown and hidden', (WidgetTester tester) async {
    await _pumpLogin(tester);

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
