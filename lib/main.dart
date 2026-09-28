import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

/// Runs in its own isolate when a push notification arrives while the app is
/// backgrounded or not running. A notification-style message (every push this
/// app sends is one) is already displayed by the OS without any code here —
/// this only exists because the plugin requires a registered handler, and it
/// re-initializes Firebase since this isolate doesn't share the one in main().
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Sends uncaught errors to Crashlytics (release builds only) so problems
/// members hit in the field show up instead of vanishing.
Future<void> _setUpErrorReporting() async {
  if (kIsWeb) return; // Crashlytics doesn't support web.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _setUpErrorReporting();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Phones are portrait-only; tablets (iPad, Android tablets) use the whole
  // screen in any orientation.
  final view = PlatformDispatcher.instance.views.first;
  final shortestSideDp = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSideDp < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // In release builds Flutter's default ErrorWidget renders as an empty box
  // with no message, which on a full-screen build failure just looks like a
  // blank white screen with nothing to go on. Show something visible instead.
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.error_outline, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'Something went wrong loading this screen.\nPlease try again.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  runApp(const ProviderScope(child: SteamApp()));
}
