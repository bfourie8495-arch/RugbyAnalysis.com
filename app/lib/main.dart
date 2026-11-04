import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/backend.dart';
import 'services/feed_service.dart';
import 'services/notifications.dart';
import 'state/app_controller.dart';
import 'theme.dart';

// `async` main is like an asyncio entry point: start Firebase (if it's set up)
// before the first screen, then load the feeds in the background.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // needed before plugins run
  final backend = await Backend.connect();
  final notifications = backend != null && alertsSupported ? Notifications(backend) : null;
  final controller = AppController(source: WebFeedSource(), backend: backend, enableAlerts: notifications?.enable);
  runApp(RugbyApp(controller: controller, notifications: notifications));
  controller.start();
}

class RugbyApp extends StatefulWidget {
  const RugbyApp({super.key, required this.controller, this.notifications});

  final AppController controller;
  final Notifications? notifications;

  @override
  State<RugbyApp> createState() => _RugbyAppState();
}

class _RugbyAppState extends State<RugbyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // A tapped notification brings you back to Matchday, where this weekend's games are.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.notifications?.start((_) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }));
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'RugbyAnalysis',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
