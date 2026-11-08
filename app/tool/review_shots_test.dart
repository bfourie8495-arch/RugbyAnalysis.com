// TEMPORARY (review only, removed before merge): renders the new stats screens from test/data.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/main.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/screens/match_screen.dart';
import 'package:rugby_analysis/screens/team_screen.dart';
import 'package:rugby_analysis/screens/tournament_screen.dart';
import 'package:rugby_analysis/services/feed_service.dart';
import 'package:rugby_analysis/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files.where((f) => File(f).existsSync())) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

class _Feeds implements FeedSource {
  @override
  Future<Map<String, dynamic>> load(String name) async => jsonDecode(File('test/data/$name.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    await _font('Poppins', ['assets/fonts/Poppins-SemiBold.ttf', 'assets/fonts/Poppins-Bold.ttf', 'assets/fonts/Poppins-ExtraBold.ttf']);
    final fig = ['assets/fonts/Figtree-Regular.ttf', 'assets/fonts/Figtree-Medium.ttf', 'assets/fonts/Figtree-SemiBold.ttf', 'assets/fonts/Figtree-Bold.ttf'];
    await _font('Figtree', fig);
    await _font('Roboto', fig);
    await _font('Noto Color Emoji', ['tool/fonts/NotoColorEmoji.ttf']);
    final fonts = Directory('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts');
    await _font('MaterialIcons', fonts.existsSync() ? [for (final f in fonts.listSync().whereType<File>()) if (f.path.toLowerCase().endsWith('materialicons-regular.otf')) f.path] : []);
  });

  Future<AppController> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final c = AppController(source: _Feeds());
    await tester.pumpWidget(RugbyApp(controller: c));
    await c.start();
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> open(WidgetTester tester, AppController c, Widget screen, String name) async {
    await tester.pumpWidget(AppScope(controller: c, child: MaterialApp(theme: Theme.of(tester.element(find.byType(Scaffold).first)), home: screen)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('review/$name.png'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1250));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('review/$name-2.png'));
  }

  testWidgets('home', (tester) async {
    await start(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('review/home.png'));
  });
  testWidgets('fixture', (tester) async {
    final c = await start(tester);
    final f = c.matchday!.men.fixtures.firstWhere((f) => f.home == 'France' && f.away == 'South Africa');
    await open(tester, c, MatchScreen(gender: Gender.men, fixture: f), 'fixture');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1250));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('review/fixture-3.png'));
  });
  testWidgets('result', (tester) async {
    final c = await start(tester);
    await open(tester, c, MatchScreen.result(gender: Gender.men, result: c.matchday!.men.results.firstWhere((r) => r.home == 'Italy')), 'result');
  });
  testWidgets('team', (tester) async {
    final c = await start(tester);
    await open(tester, c, const TeamScreen(gender: Gender.men, team: 'South Africa'), 'team');
  });
  testWidgets('tournament', (tester) async {
    final c = await start(tester);
    await open(tester, c, const TournamentScreen(id: '6n'), 'tournament');
  });
}
