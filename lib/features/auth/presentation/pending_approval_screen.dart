import 'package:flutter/material.dart';

import 'account_status_view.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountStatusView(
      icon: Icons.hourglass_top,
      title: "You're almost in!",
      message: 'A STEAM Club admin needs to approve your request before you can see the member directory, '
          'news, and events. This page updates automatically as soon as you\'re in, so you can close the app '
          'and come back later.',
    );
  }
}
