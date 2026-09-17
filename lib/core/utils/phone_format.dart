import 'package:flutter/services.dart';

// US-only for now, matching the fixed +1 prefix used at signup.

/// Formats a stored phone number for display, e.g. "(123) 456-7890".
/// Falls back to the raw string if it isn't a recognizable 10-digit US number.
String formatPhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final tenDigits = digits.length == 11 && digits.startsWith('1') ? digits.substring(1) : digits;
  if (tenDigits.length != 10) return raw;
  return '(${tenDigits.substring(0, 3)}) ${tenDigits.substring(3, 6)}-${tenDigits.substring(6)}';
}

/// Live-formats digits as "(123) 456-7890" while the user types into a
/// phone number field, ignoring non-digit input and capping at 10 digits.
class UsPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.substring(0, digits.length.clamp(0, 10));
    final formatted = _formatDigits(capped);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }

  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return '($digits';
    if (digits.length <= 6) return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
}
