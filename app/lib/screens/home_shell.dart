import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'chat_screen.dart';
import 'clubs_screen.dart';
import 'matchday_screen.dart';
import 'me_screen.dart';
import 'tournaments_screen.dart';

/// The five tabs. IndexedStack keeps each tab's scroll position when you switch.
/// The World Cup lives at the top of Tournaments (and on Matchday's strip).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final unread = c.unreadRooms, tab = c.tab;
    return Scaffold(
        body: SafeArea(
          child: IndexedStack(index: tab, children: const [
            MatchdayScreen(),
            TournamentsScreen(),
            ClubsScreen(),
            ChatScreen(),
            MeScreen(),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: c.setTab,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Matchday'),
            const NavigationDestination(icon: Icon(Icons.table_chart_outlined), selectedIcon: Icon(Icons.table_chart), label: 'Tournaments'),
            const NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Clubs'),
            NavigationDestination(
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.forum_outlined)),
              selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.forum)),
              label: 'Chat',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
          ],
        ),
    );
  }
}
