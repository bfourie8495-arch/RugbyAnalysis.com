import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/main.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/live.dart';
import 'package:rugby_analysis/screens/match_screen.dart';
import 'package:rugby_analysis/services/feed_service.dart';
import 'package:rugby_analysis/state/app_controller.dart';
import 'package:rugby_analysis/widgets/live.dart';
import 'package:rugby_analysis/widgets/match_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Files implements FeedSource {
  @override
  Future<Map<String, dynamic>> load(String name) async => jsonDecode(File('test/data/$name.json').readAsStringSync()) as Map<String, dynamic>;
}

/// Hands back whatever live.json the test sets, and counts the downloads.
class _Live implements LiveSource {
  Map<String, dynamic>? doc;
  int calls = 0;

  @override
  Future<Map<String, dynamic>?> load() async {
    calls++;
    return doc;
  }
}

// England v Australia, the first fixture in test/data/matchday.json (kick-off 2026-11-08 15:10 UTC), as
// worker/live.js writes it 34 minutes in.
Map<String, dynamic> _doc({String st = 'live', String min = '34', int hs = 10, int as = 7}) => {
      'asOf': '2026-11-08T15:44:00Z',
      'games': [
        {
          'id': '604001', 'g': 'm', 'h': 'England', 'a': 'Australia', 'ko': '2026-11-08T15:10:00Z', 'st': st, 'min': min, 'hs': hs, 'as': as,
          'ev': [
            [4, 'P', 'h', 'G. Ford'],
            [12, 'T', 'a', 'M. Jorgensen'],
            [13, 'C', 'a', 'T. Lynagh'],
            [20, 'Y', 'a', 'H. Wilson'],
            [27, 'T', 'h', 'T. Curry'],
            [28, 'C', 'h', 'G. Ford'],
          ],
        },
      ],
    };

final _ko = DateTime.utc(2026, 11, 8, 15, 10);

void main() {
  test('live.json as the Worker writes it', () {
    final f = LiveFeed.fromJson(_doc());
    final g = f.find(Gender.men, 'Australia', 'England')!; // either way round
    expect(g.state, LiveState.live);
    expect(g.label, "34'");
    expect(g.scoreOf('England'), 10);
    expect(g.scoreOf('Australia'), 7);
    expect(g.events.map((e) => e.what), ['Penalty goal', 'Try', 'Conversion', 'Yellow card', 'Try', 'Conversion']);
    expect(g.events[1].home, isFalse);
    expect(f.find(Gender.women, 'England', 'Australia'), isNull);
    expect(LiveFeed.fromJson(_doc(st: 'ht')).games.single.label, 'HT');
    expect(LiveFeed.fromJson(_doc(st: 'ft')).games.single.label, 'FT');
    expect(LiveFeed.fromJson(_doc(st: 'pre')).games.single.started, isFalse);
    expect(LiveFeed.fromJson(const {}).games, isEmpty);
  });

  test('live scores are only asked for around a kick-off', () {
    expect(inLiveWindow(_ko, _ko.subtract(const Duration(minutes: 16))), isFalse);
    expect(inLiveWindow(_ko, _ko.subtract(const Duration(minutes: 15))), isTrue);
    expect(inLiveWindow(_ko, _ko.add(const Duration(hours: 3))), isTrue);
    expect(inLiveWindow(_ko, _ko.add(const Duration(hours: 3, minutes: 1))), isFalse);
    expect(inLiveWindow(null, _ko), isFalse);
  });

  test('the controller downloads nothing when no Test is on, and the score once one is', () async {
    SharedPreferences.setMockInitialValues({});
    final live = _Live()..doc = _doc();
    final c = AppController(source: _Files(), liveSource: live);
    await c.refresh();
    final calls = live.calls; // refresh() takes one look with the real clock
    await c.pollLive(now: DateTime.utc(2026, 11, 1));
    expect(live.calls, calls);
    expect(c.live, isNull);
    await c.pollLive(now: _ko.add(const Duration(minutes: 34)));
    expect(live.calls, calls + 1);
    final f = c.matchday!.men.fixtures.first;
    expect(c.liveFor(Gender.men, f)!.homeScore, 10);
    c.setForeground(false);
    await c.pollLive(now: _ko.add(const Duration(minutes: 35)));
    expect(live.calls, calls + 1, reason: 'nothing in the background');
    c.dispose();
  });

  testWidgets('a Test being played shows its score and a timeline on its match screen', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final live = _Live()..doc = _doc();
    final c = AppController(source: _Files(), liveSource: live);
    await tester.pumpWidget(RugbyApp(controller: c));
    await c.start();
    await c.pollLive(now: _ko.add(const Duration(minutes: 34)));
    await tester.pumpAndSettle();
    final f = c.matchday!.men.fixtures.first;
    await tester.pumpWidget(RugbyApp(controller: c)); // same app; the match screen pushed below
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => MatchScreen(gender: Gender.men, fixture: f)));
    await tester.pumpAndSettle();
    expect(find.text('Live'), findsWidgets); // the title bar
    expect(find.text('10–7'), findsNWidgets(2)); // the score, and after the latest conversion in the timeline
    expect(find.text("34'"), findsOneWidget);
    expect(find.byType(LiveTimeline), findsOneWidget);
    expect(find.text('Yellow card'), findsOneWidget);
    expect(find.text('Australia · M. Jorgensen'), findsOneWidget);
    expect(find.text('Remind me before kick-off'), findsNothing);
    c.dispose();
  });

  testWidgets('the kick-off block shows the minute, then full time', (tester) async {
    final f = Fixture(date: '2026-11-08', home: 'England', away: 'Australia', kickOff: _ko);
    Future<void> show(LiveGame g) => tester.pumpWidget(MaterialApp(home: Scaffold(body: KickOffBlock(fixture: f, live: g))));
    await show(LiveFeed.fromJson(_doc()).games.single);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text("34'"), findsOneWidget);
    await show(LiveFeed.fromJson(_doc(st: 'ft')).games.single);
    expect(find.text('FULL TIME'), findsOneWidget);
    expect(find.text('FT'), findsOneWidget);
  });
}
