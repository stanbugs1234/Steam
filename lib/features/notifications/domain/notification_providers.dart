import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reminder_service.dart';

final flutterLocalNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(flutterLocalNotificationsPluginProvider));
});
