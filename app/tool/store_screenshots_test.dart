// Renders the Google Play phone screenshots (1080 x 1920) with the real fonts, into store/screenshots/.
// Not part of the normal test run. GitHub makes them (.github/workflows/app-store-screenshots.yml),
// with the latest feeds from rugbyanalysis.com in tool/live/ and an emoji font for the flags in
// tool/fonts/. By hand, from the app folder (FLUTTER_ROOT set):
//   flutter test tool/store_screenshots_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files.where((f) => File(f).existsSync())) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

/// The latest feeds if the workflow downloaded them, otherwise the copies the tests use.
class _Feeds implements FeedSource {
  @override
  Future<Map<String, dynamic>> load(String name) async {
    final live = File('tool/live/$name.json');
    final file = live.existsSync() ? live : File('test/data/$name.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

Finder _listOf(Type screen) => find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first;

void main() {
  setUpAll(() async {
    await _font('Poppins', ['assets/fonts/Poppins-SemiBold.ttf', 'assets/fonts/Poppins-Bold.ttf', 'assets/fonts/Poppins-ExtraBold.ttf']);
    await _font('Figtree', [
      'assets/fonts/Figtree-Regular.ttf',
      'assets/fonts/Figtree-Medium.ttf',
      'assets/fonts/Figtree-SemiBold.ttf',
      'assets/fonts/Figtree-Bold.ttf',
    ]);
    // Widgets that don't name a font (chips, for one) use the platform default, Roboto on Android.
    // Tests have no Roboto, so Figtree stands in for it here.
    await _font('Roboto', ['assets/fonts/Figtree-Regular.ttf', 'assets/fonts/Figtree-SemiBold.ttf', 'assets/fonts/Figtree-Bold.ttf']);
    await _font('Noto Color Emoji', ['tool/fonts/NotoColorEmoji.ttf']);
    // The icon font's file name has changed case between Flutter versions, so look for it.
    final fonts = Directory('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts');
    final icons = fonts.existsSync()
        ? fonts.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('materialicons-regular.otf')).map((f) => f.path).toList()
        : <String>[];
    await _font('MaterialIcons', icons);
  });

  Future<AppController> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final c = AppController(source: _Feeds());
    await tester.pumpWidget(RugbyApp(controller: c));
    await c.start();
    // A fan who follows South Africa and has alerts on.
    c.toggleFollow(Gender.men, 'South Africa');
    c.setAlerts(c.alerts.copyWith(on: true));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../store/screenshots/$name.png'));
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  /// Scrolls [screen]'s list until [f] is built, then moves it to the top of the screen.
  Future<void> scrollToTop(WidgetTester tester, Type screen, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await tester.drag(_listOf(screen), const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final y = tester.getTopLeft(f.first).dy;
    await tester.drag(_listOf(screen), Offset(0, -(y - 110)));
    await tester.pumpAndSettle();
  }

  testWidgets('1 matchday', (tester) async {
    await start(tester);
    await shoot(tester, '1-matchday');
  });

  testWidgets('2 match preview', (tester) async {
    await start(tester);
    await scrollToTop(tester, MatchdayScreen, find.byType(FixtureTile));
    await tester.tap(find.byType(FixtureTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
    await shoot(tester, '2-match');
  });

  testWidgets('3 world cup predictions', (tester) async {
    await start(tester);
    await tapTab(tester, 'Tournaments');
    await tester.tap(find.descendant(of: find.byType(TournamentsScreen), matching: find.text('Rugby World Cup 2027')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Predictions'));
    await tester.pumpAndSettle();
    await scrollToTop(tester, WorldCupScreen, find.descendant(of: find.byType(WorldCupScreen), matching: find.text('Who wins it?')));
    await shoot(tester, '3-world-cup');
  });

  testWidgets('4 nations championship', (tester) async {
    await start(tester);
    await tapTab(tester, 'Tournaments');
    await tester.tap(find.descendant(of: find.byType(TournamentsScreen), matching: find.textContaining('Nations Championship')).first);
    await tester.pumpAndSettle();
    expect(find.byType(TournamentScreen), findsOneWidget);
    await shoot(tester, '4-tournament');
  });

  testWidgets('5 your teams and alerts', (tester) async {
    await start(tester);
    await tapTab(tester, 'Me');
    await scrollToTop(tester, MeScreen, find.text('Alerts'));
    await shoot(tester, '5-alerts');
  });
}
