import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/main.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/screens/match_screen.dart';
import 'package:rugby_analysis/screens/matchday_screen.dart';
import 'package:rugby_analysis/screens/me_screen.dart';
import 'package:rugby_analysis/screens/tournament_screen.dart';
import 'package:rugby_analysis/screens/tournaments_screen.dart';
import 'package:rugby_analysis/screens/world_cup_screen.dart';
import 'package:rugby_analysis/services/feed_service.dart';
import 'package:rugby_analysis/state/app_controller.dart';
import 'package:rugby_analysis/widgets/match_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the real feed copies in test/data instead of the website.
class FileFeeds implements FeedSource {
  FileFeeds() : _feeds = {for (final n in ['matchday', 'tournaments']) n: File('test/data/$n.json').readAsStringSync()};

  final Map<String, String> _feeds;

  @override
  Future<Map<String, dynamic>> load(String name) async => jsonDecode(_feeds[name]!) as Map<String, dynamic>;
}

Finder tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// The main list of a screen (the tabs are all built at once, so finders say which screen they mean).
Finder listOf(Type screen) => find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first;
Finder textIn(Type screen, String text) => find.descendant(of: find.byType(screen), matching: find.text(text));

/// Scrolls a screen's list down until [f] matches at least one widget, then brings the first fully into view.
/// (A ListView only builds what's on screen, so anything further down doesn't exist until you scroll to it.)
Future<void> scrollTo(WidgetTester tester, Type screen, Finder f) async {
  for (var i = 0; i < 50 && f.evaluate().isEmpty; i++) {
    await tester.drag(listOf(screen), const Offset(0, -300));
    await tester.pump();
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
}

Future<AppController> startApp(WidgetTester tester) async {
  // A phone-sized screen (390 x 844), so layout problems show up as they would on a phone.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final c = AppController(source: FileFeeds());
  await tester.pumpWidget(RugbyApp(controller: c));
  await c.start();
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('Matchday shows the World Cup strip, fixtures with picks and results', (tester) async {
    await startApp(tester);
    expect(find.textContaining('Rugby World Cup 2027'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Up next'), 300, scrollable: listOf(MatchdayScreen));
    expect(find.text('Up next'), findsOneWidget);
    await scrollTo(tester, MatchdayScreen, find.text('Model pick '));
    expect(find.text('Model pick '), findsWidgets);
    await tester.scrollUntilVisible(find.text('Latest results'), 300, scrollable: listOf(MatchdayScreen));
    expect(find.text('Latest results'), findsOneWidget);
  });

  testWidgets('Tournaments open a table with predictions', (tester) async {
    await startApp(tester);
    await tester.tap(tab('Tournaments'));
    await tester.pumpAndSettle();
    await tester.tap(textIn(TournamentsScreen, 'Nations Championship 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Northern group'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Who wins it?'), 300, scrollable: listOf(TournamentScreen));
    expect(find.text('Who wins it?'), findsOneWidget);
  });

  testWidgets('A fixture shows the head-to-head and both teams’ numbers', (tester) async {
    await startApp(tester);
    await scrollTo(tester, MatchdayScreen, find.byType(FixtureTile));
    await tester.tap(find.byType(FixtureTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Head to head'), 300, scrollable: listOf(MatchScreen));
    expect(find.text('Head to head'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Points scored a game'), 300, scrollable: listOf(MatchScreen));
    expect(find.text('Points scored a game'), findsOneWidget);
  });

  testWidgets('A result opens its match stats', (tester) async {
    final c = await startApp(tester);
    final r = c.matchday!.men.results.firstWhere((r) => r.detail?.hasScoring ?? false);
    await tester.pumpWidget(AppScope(controller: c, child: MaterialApp(home: MatchScreen.result(gender: Gender.men, result: r))));
    await tester.pumpAndSettle();
    expect(find.text('${r.homeScore}–${r.awayScore}'), findsWidgets);
    expect(find.text('Match stats'), findsOneWidget);
    expect(find.text('Tries'), findsOneWidget);
  });

  testWidgets('A tournament shows its stats and top try scorers', (tester) async {
    await startApp(tester);
    await tester.tap(tab('Tournaments'));
    await tester.pumpAndSettle();
    await tester.tap(textIn(TournamentsScreen, 'Nations Championship 2026'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tournament stats'), 300, scrollable: listOf(TournamentScreen));
    expect(find.text('Tournament stats'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Top try scorers'), 300, scrollable: listOf(TournamentScreen));
    expect(find.text('Top try scorers'), findsOneWidget);
  });

  testWidgets('World Cup shows pools, predictions and a team’s scenarios', (tester) async {
    await startApp(tester);
    await tester.tap(tab('World Cup'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(textIn(WorldCupScreen, 'POOL B'), 300, scrollable: listOf(WorldCupScreen));
    expect(textIn(WorldCupScreen, 'POOL B'), findsOneWidget);
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, 'Predictions'), -300, scrollable: listOf(WorldCupScreen));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Predictions'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(textIn(WorldCupScreen, 'Who wins it?'), 300, scrollable: listOf(WorldCupScreen));
    expect(textIn(WorldCupScreen, 'Who wins it?'), findsOneWidget);
    await tester.scrollUntilVisible(textIn(WorldCupScreen, 'SCENARIOS'), 300, scrollable: listOf(WorldCupScreen));
    expect(find.textContaining('Top Pool'), findsWidgets);
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, 'Knockouts'), -300, scrollable: listOf(WorldCupScreen));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Knockouts'));
    await tester.pumpAndSettle();
    expect(textIn(WorldCupScreen, 'Round of 16'), findsWidgets);
  });

  testWidgets('Following a team from its page shows it under Me', (tester) async {
    final c = await startApp(tester);
    await tester.tap(tab('World Cup'));
    await tester.pumpAndSettle();
    await scrollTo(tester, WorldCupScreen, textIn(WorldCupScreen, 'South Africa'));
    await tester.tap(textIn(WorldCupScreen, 'South Africa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(c.follows, contains('m|South Africa'));
    expect(find.text('Following'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(tab('Me'));
    await tester.pumpAndSettle();
    expect(find.text('South Africa'), findsWidgets);
    expect(find.text('Turn on alerts'), findsOneWidget);
    // Turning alerts on shows their settings (a card of tappable rows).
    await tester.tap(find.text('Turn on alerts'));
    await tester.pumpAndSettle();
    expect(c.alerts.on, isTrue);
    expect(find.text('Weekend heads-up'), findsOneWidget);
    // Delete my data clears your teams.
    await scrollTo(tester, MeScreen, find.text('Delete my data'));
    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(c.follows, isEmpty);
    expect(find.text('Your data has been deleted.'), findsOneWidget);
  });
}
