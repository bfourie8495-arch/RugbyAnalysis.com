import 'package:flutter/material.dart';

import 'models/chat.dart';
import 'screens/chat_screen.dart';
import 'screens/home_shell.dart';
import 'screens/room_screen.dart';
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
  final controller = AppController(source: WebFeedSource(), backend: backend, enableAlerts: notifications?.enable, disableAlerts: notifications?.disable,
      refreshAlerts: notifications?.refresh);
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
    // A tapped chat notification opens its room; any other brings you back to Matchday,
    // where this weekend's games are.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.notifications?.start((data) {
          final nav = _navigatorKey.currentState;
          nav?.popUntil((route) => route.isFirst);
          final room = data['room'];
          if (room is String && room.isNotEmpty) {
            widget.controller.setTab(AppTab.chat);
            final ctx = _navigatorKey.currentContext;
            if (ctx != null) openRoom(ctx, room);
          } else {
            widget.controller.setTab(AppTab.matchday);
          }
        }));
  }

  /// Invite links: rugbyanalysis://app/join/CODE (from the website's join page, see worker/index.js)
  /// arrives as the route '/join/CODE' and opens the join screen with the code filled in.
  static Route<void>? _route(RouteSettings s) {
    final code = joinCodeFromRoute(s.name);
    if (code == null) return s.name == '/' ? MaterialPageRoute(builder: (_) => const HomeShell(), settings: s) : null;
    return MaterialPageRoute(builder: (_) => JoinRoomScreen(initialCode: code), settings: s);
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
        // No `home:` (Flutter doesn't allow it with onGenerateInitialRoutes): HomeShell is the first route.
        onGenerateRoute: _route,
        // Started from an invite link: home underneath, the join screen on top.
        onGenerateInitialRoutes: (name) => [
          MaterialPageRoute(builder: (_) => const HomeShell(), settings: const RouteSettings(name: '/')),
          if (joinCodeFromRoute(name) != null) _route(RouteSettings(name: name))!,
        ],
      ),
    );
  }
}
