import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Text whose web links, email addresses and phone numbers are tappable.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final _pattern = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)|([\w.+-]+@[\w-]+(?:\.[\w-]+)+)|(\+?\d[\d\s().-]{7,}\d)',
    caseSensitive: false,
  );

  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing sensible to do if the device can't open it.
    }
  }

  Uri? _uriFor(RegExpMatch m) {
    var text = m.group(0)!;
    if (m.group(1) != null) {
      // Trailing punctuation belongs to the sentence, not the link.
      text = text.replaceFirst(RegExp(r'[.,;:!?)]+$'), '');
      return Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    }
    if (m.group(2) != null) return Uri(scheme: 'mailto', path: text);
    final digits = text.replaceAll(RegExp(r'[^\d+]'), '');
    return digits.length >= 10 ? Uri(scheme: 'tel', path: digits) : null;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _pattern.allMatches(widget.text)) {
      final uri = _uriFor(m);
      if (uri == null) continue;
      if (m.start > cursor) spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: m.group(0), style: linkStyle, recognizer: recognizer));
      cursor = m.end;
    }
    if (cursor < widget.text.length) spans.add(TextSpan(text: widget.text.substring(cursor)));

    return Text.rich(TextSpan(style: base, children: spans));
  }
}
