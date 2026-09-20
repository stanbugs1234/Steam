import 'package:flutter/material.dart';

import 'account_status_view.dart';

class DeniedScreen extends StatelessWidget {
  const DeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountStatusView(
      icon: Icons.block,
      iconColor: Theme.of(context).colorScheme.error,
      title: "We couldn't approve your STEAM Club request",
      message: "If you think this doesn't look right, please reach out to a club admin and we'll sort it out.",
    );
  }
}
