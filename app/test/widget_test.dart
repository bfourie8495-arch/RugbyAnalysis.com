import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/main.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/chat.dart';
import 'package:rugby_analysis/screens/chat_screen.dart';
import 'package:rugby_analysis/screens/club_screen.dart';
import 'package:rugby_analysis/screens/clubs_screen.dart';
import 'package:rugby_analysis/screens/insights_screen.dart';
import 'package:rugby_analysis/screens/room_screen.dart';
import 'package:rugby_analysis/screens/match_screen.dart';
import 'package:rugby_analysis/screens/matchday_screen.dart';
import 'package:rugby_analysis/screens/me_screen.dart';
import 'package:rugby_analysis/screens/team_screen.dart';
import 'package:rugby_analysis/screens/tournament_screen.dart';
import 'package:rugby_analysis/screens/tournaments_screen.dart';
import 'package:rugby_analysis/screens/world_cup_screen.dart';
import 'package:rugby_analysis/services/chat_service.dart';
import 'package:rugby_analysis/services/feed_service.dart';
import 'package:rugby_analysis/state/app_controller.dart';
import 'package:rugby_analysis/widgets/share_card.dart';
import 'package:rugby_analysis/widgets/match_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the real feed copies in test/data instead of the website.
class FileFeeds implements FeedSource {
  FileFeeds() : _feeds = {for (final n in ['matchday', 'tournaments', 'clubs']) n: File('test/data/$n.json').readAsStringSync()};

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

/// The World Cup now opens from the top of Tournaments.
Future<void> openWorldCup(WidgetTester tester) async {
  await tester.tap(tab('Tournaments'));
  await tester.pumpAndSettle();
  await tester.tap(textIn(TournamentsScreen, 'Rugby World Cup 2027'));
  await tester.pumpAndSettle();
}

Future<AppController> startApp(WidgetTester tester, {ChatService? chat}) async {
  // A phone-sized screen (390 x 844), so layout problems show up as they would on a phone.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final c = AppController(source: FileFeeds(), chat: chat);
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
    final c = await startApp(tester);
    await scrollTo(tester, MatchdayScreen, find.byType(FixtureTile));
    await tester.tap(find.byType(FixtureTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Head to head'), 300, scrollable: listOf(MatchScreen));
    expect(find.text('Head to head'), findsOneWidget);
    final f = tester.widget<MatchScreen>(find.byType(MatchScreen)).fixture!;
    if (c.matchday!.men.sharedOpponents(f.home, f.away) != null) {
      await tester.scrollUntilVisible(find.text('Against the same teams'), 300, scrollable: listOf(MatchScreen));
      expect(find.text('Against the same teams'), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Points scored a game'), 300, scrollable: listOf(MatchScreen));
    expect(find.text('Points scored a game'), findsOneWidget);
  });

  testWidgets('A fixture links to the website and shares the pick; a result shares the score', (tester) async {
    final c = await startApp(tester);
    final f = c.matchday!.men.fixtures.first;
    await tester.pumpWidget(AppScope(controller: c, child: MaterialApp(home: MatchScreen(gender: Gender.men, fixture: f))));
    await tester.pumpAndSettle();
    // Sharing sits in the top bar, apart from "Watch with friends".
    expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Share the pick')), findsOneWidget);
    await scrollTo(tester, MatchScreen, find.text('Full head to head on the website'));
    expect(find.text('Full head to head on the website'), findsOneWidget);

    // Share opens a sheet with the card and two ways to send it
    await tester.tap(find.byTooltip('Share the pick'));
    await tester.pumpAndSettle();
    expect(find.text('Share picture'), findsOneWidget);
    expect(find.text('Share as text'), findsOneWidget);
    expect(find.text('THE MODEL’S PICK'), findsOneWidget);
    expect(find.byType(PickShareCard), findsOneWidget);
    // the card draws to a 1080-wide picture
    final boundary = find.ancestor(of: find.byType(PickShareCard), matching: find.byType(RepaintBoundary)).first;
    final png = await tester.runAsync(() => cardPng(tester.widget<RepaintBoundary>(boundary).key! as GlobalKey));
    expect(png, isNotNull);
    expect(png!.length, greaterThan(1000));
    Navigator.of(tester.element(find.text('Share picture'))).pop();
    await tester.pumpAndSettle();

    final r = c.matchday!.men.results.first;
    await tester.pumpWidget(AppScope(controller: c, child: MaterialApp(home: MatchScreen.result(gender: Gender.men, result: r))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Share the score'), findsOneWidget);
    expect(find.byTooltip('Share the pick'), findsNothing);
  });

  testWidgets('A team page links to its full record on the website', (tester) async {
    final c = await startApp(tester);
    await tester.pumpWidget(AppScope(controller: c, child: const MaterialApp(home: TeamScreen(gender: Gender.women, team: 'England'))));
    await tester.pumpAndSettle();
    await scrollTo(tester, TeamScreen, find.text('Full record on the website'));
    expect(find.text('Full record on the website'), findsOneWidget);
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

  testWidgets('A team page shows the season so far and the scoring trend', (tester) async {
    final c = await startApp(tester);
    await tester.pumpWidget(AppScope(controller: c, child: const MaterialApp(home: TeamScreen(gender: Gender.men, team: 'South Africa'))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Season so far'), 300, scrollable: listOf(TeamScreen));
    expect(find.text('Season so far'), findsOneWidget);
    // the trend's title is its finding
    await tester.scrollUntilVisible(find.text('Points scored above the line, conceded below. Oldest on the left.'), 300, scrollable: listOf(TeamScreen));
    expect(find.textContaining(RegExp(r'^(Holding steady|Up \d+ points a game|Down \d+ points a game)$')), findsOneWidget);
  });

  testWidgets('Talking points lists the title race, upsets and try scorers', (tester) async {
    final c = await startApp(tester);
    await tester.pumpWidget(AppScope(controller: c, child: const MaterialApp(home: InsightsScreen(gender: Gender.men))));
    await tester.pumpAndSettle();
    expect(find.text('Nations Championship 2026'), findsOneWidget);
    // section titles are findings, written from the data
    final u = c.matchday!.men.upsets.first;
    final title = '${u.winner} at ${u.winnerChance}%: the year’s biggest upset';
    await tester.scrollUntilVisible(find.text(title), 300, scrollable: listOf(InsightsScreen));
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('An upset says so on its result', (tester) async {
    final c = await startApp(tester);
    final r = c.matchday!.men.upsets.first;
    await tester.pumpWidget(AppScope(controller: c, child: MaterialApp(home: MatchScreen.result(gender: Gender.men, result: r))));
    await tester.pumpAndSettle();
    expect(find.textContaining('chance beforehand', findRichText: true), findsOneWidget);
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
    await openWorldCup(tester);
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
    await openWorldCup(tester);
    await scrollTo(tester, WorldCupScreen, textIn(WorldCupScreen, 'South Africa'));
    await tester.tap(textIn(WorldCupScreen, 'South Africa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(c.follows, contains('m|South Africa'));
    expect(find.text('Following'), findsOneWidget);
    await tester.pageBack(); // the team page
    await tester.pumpAndSettle();
    await tester.pageBack(); // the World Cup
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

  testWidgets('Clubs: a competition’s table, then a club you can follow', (tester) async {
    final c = await startApp(tester);
    await tester.tap(tab('Clubs'));
    await tester.pumpAndSettle();
    expect(textIn(ClubsScreen, 'United Rugby Championship'), findsOneWidget);
    await scrollTo(tester, ClubsScreen, textIn(ClubsScreen, 'Glasgow Warriors'));
    await tester.tap(textIn(ClubsScreen, 'Glasgow Warriors').first);
    await tester.pumpAndSettle();
    expect(find.byType(ClubScreen), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(c.clubFollows, contains('glasgow'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Your clubs now lead the tab.
    await tester.drag(listOf(ClubsScreen), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(textIn(ClubsScreen, 'Your clubs'), findsOneWidget);
    // Another competition.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Premiership'));
    await tester.pumpAndSettle();
    expect(textIn(ClubsScreen, 'Premiership Rugby'), findsOneWidget);
    // And under Me.
    await tester.tap(tab('Me'));
    await tester.pumpAndSettle();
    expect(textIn(MeScreen, 'Clubs you follow'), findsOneWidget);
  });

  testWidgets('Chat without a server says so', (tester) async {
    await startApp(tester);
    await tester.tap(tab('Chat'));
    await tester.pumpAndSettle();
    expect(textIn(ChatScreen, 'Chat isn’t available'), findsOneWidget);
  });

  testWidgets('Chat: make a room, invite, send a message, report one', (tester) async {
    final chat = MemoryChat();
    final c = await startApp(tester, chat: chat);
    await tester.tap(tab('Chat'));
    await tester.pumpAndSettle();
    expect(textIn(ChatScreen, 'No rooms yet'), findsOneWidget);

    await tester.tap(find.text('New room'));
    await tester.pumpAndSettle();
    // First time: your name.
    await tester.enterText(find.byType(TextField), 'Brendon');
    await tester.pump(); // Save switches on once there's a name
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(c.myName, 'Brendon');
    // Then the room's name.
    await tester.enterText(find.byType(TextField), 'Saturday rugby');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(find.text('Invite friends to Saturday rugby'), findsOneWidget);
    final room = c.rooms.single;
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, spacedCode(room.id));
    await tester.tapAt(const Offset(200, 60)); // close the sheet
    await tester.pumpAndSettle();

    await tester.enterText(find.descendant(of: find.byType(RoomScreen), matching: find.byType(TextField)), 'Kick-off in ten!');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Kick-off in ten!'), findsOneWidget);

    // A friend writes; reporting them hides their messages.
    chat.seed(
      Room(id: room.id, name: room.name, ownerUid: 'me', members: const ['me', 'tom'], names: const {'me': 'Brendon', 'tom': 'Tom'}),
      [
        ChatMessage(id: 'a', uid: 'me', name: 'Brendon', text: 'Kick-off in ten!', at: DateTime.now()),
        ChatMessage(id: 'b', uid: 'tom', name: 'Tom', text: 'Nasty message', at: DateTime.now()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Nasty message'), findsOneWidget);
    await tester.longPress(find.text('Nasty message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abuse or bullying'));
    await tester.pumpAndSettle();
    expect(chat.reports, hasLength(1));
    expect(c.blocked, contains('tom'));
    expect(find.text('Nasty message'), findsNothing);
  });

  testWidgets('Chat: join a friend’s room with its code', (tester) async {
    final chat = MemoryChat();
    chat.seed(const Room(id: 'ABCDEFGHJKMN', name: 'Boks fans', ownerUid: 'tom', members: ['tom'], names: {'tom': 'Tom'}));
    final c = await startApp(tester, chat: chat);
    c.myName = 'Brendon';
    await tester.tap(tab('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abcd-efgh-jkmn');
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(c.rooms.single.members, containsAll(['tom', 'me']));
    expect(find.text('You and Tom'), findsOneWidget);
  });
}
