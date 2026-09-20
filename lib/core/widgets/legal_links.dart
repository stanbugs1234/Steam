import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../legal_links.dart';

/// "By continuing you agree to…" with links to the Terms of Use and Privacy
/// Policy. Shown on the sign-in and sign-up screens; both stores require the
/// privacy policy to be reachable from inside the app.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.prefix = 'By continuing, you agree to the'});

  final String prefix;

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing useful to do if the device can't open a web link.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      children: [
        Text(prefix, textAlign: TextAlign.center, style: muted),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => _open(termsOfUseUrl),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Terms of Use'),
            ),
            Text('and', style: muted),
            TextButton(
              onPressed: () => _open(privacyPolicyUrl),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }
}
