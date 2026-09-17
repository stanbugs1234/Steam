import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
