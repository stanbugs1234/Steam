import 'dart:async';
import 'dart:io' show SocketException;

import 'package:firebase_core/firebase_core.dart';

/// Turns whatever was thrown into one plain sentence a member can act on.
/// Raw exception text (Firebase paths, error codes) is never shown to people;
/// it belongs in crash reports and debug logs.
String friendlyError(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is SocketException || error is TimeoutException) return _offline;

  if (error is FirebaseException) {
    switch (error.code) {
      // Sign-in / sign-up
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return "That email and password don't match. Please check them and try again.";
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account with that email already exists. Try signing in instead.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'user-disabled':
        return 'This account has been disabled. Please contact the club.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'invalid-phone-number':
        return 'That phone number doesn\'t look right. Please check it and try again.';
      case 'invalid-verification-code':
        return "That code isn't right. Please check it and try again.";
      case 'session-expired':
      case 'code-expired':
        return 'That code has expired. Please request a new one.';
      case 'quota-exceeded':
        return "We can't send any more codes right now. Please try again later.";
      case 'captcha-check-failed':
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return "We couldn't verify this device. Please try again in a moment.";
      case 'requires-recent-login':
        return 'For your security, please sign out, sign back in, and try again.';
      case 'operation-not-allowed':
        return "This sign-in method isn't available right now. Please contact the club.";
      // Connectivity
      case 'network-request-failed':
      case 'unavailable':
      case 'deadline-exceeded':
      case 'retry-limit-exceeded':
        return _offline;
      // Data access
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return "You don't have permission to do that.";
      case 'not-found':
      case 'object-not-found':
        return "We couldn't find that. It may have been removed.";
      case 'resource-exhausted':
        return 'The service is busy right now. Please try again shortly.';
    }
  }

  return fallback;
}

const _offline = "Can't reach the server. Please check your connection and try again.";
