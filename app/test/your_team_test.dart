import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/stage.dart';
import 'package:rugby_analysis/services/feed_service.dart';
import 'package:rugby_analysis/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Files implements FeedSource {
  @override
  Future<Map<String, dynamic>> load(String name) async => jsonDecode(File('test/data/$name.json').readAsStringSync()) as Map<String, dynamic>;
}

Future<AppController> _started() async {
  SharedPreferences.setMockInitialValues({});
  final c = AppController(source: _Files());
  await c.start();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('minor Tests', () {
    test('Pakistan v Uzbekistan is hidden, a top-12 side is not', () async {
      final c = await _started();
      expect(c.isMinorTest(Gender.men, 'Pakistan', 'Uzbekistan'), isTrue);
      expect(c.isMinorTest(Gender.men, 'Ireland', 'Argentina'), isFalse);
      expect(c.isMinorTest(Gender.men, 'Fiji', 'Paraguay'), isFalse, reason: 'Fiji are in the top 12');
    });

    test('following a smaller nation brings its Tests back', () async {
      final c = await _started();
      c.toggleFollow(Gender.men, 'Uzbekistan');
      expect(c.isMinorTest(Gender.men, 'Pakistan', 'Uzbekistan'), isFalse);
    });

    test('the Show all setting is remembered', () async {
      final c = await _started();
      c.setShowAllTests(true);
      await Future<void>.delayed(Duration.zero);
      final again = AppController(source: _Files());
      await again.start();
      expect(again.showAllTests, isTrue);
    });
  });

  group('your team', () {
    test('is the first team you follow, and can be changed', () async {
      final c = await _started();
      expect(c.myTeamKey, isNull);
      c.toggleFollow(Gender.men, 'Ireland');
      c.toggleFollow(Gender.men, 'South Africa');
      expect(c.isMyTeam(Gender.men, 'Ireland'), isTrue);
      c.makeMyTeam(Gender.men, 'South Africa');
      expect(c.isMyTeam(Gender.men, 'South Africa'), isTrue);
      expect(c.follows.toList(), ['m|South Africa', 'm|Ireland'], reason: 'nobody is unfollowed');
      c.toggleFollow(Gender.men, 'South Africa');
      expect(c.isMyTeam(Gender.men, 'Ireland'), isTrue, reason: 'the next team you follow takes over');
    });
  });

  group('where it’s at', () {
    late TournamentsFeed feed;
    setUpAll(() => feed = TournamentsFeed.fromJson(jsonDecode(File('test/data/tournaments.json').readAsStringSync()) as Map<String, dynamic>));

    test('a live league says which round is next, and what comes after', () {
      final nc = feed.byId('nc')!;
      expect(whereItsAt(nc, now: DateTime.utc(2026, 10, 20)), 'After round 3 of 6. Round 4 starts Fri 6 Nov. Then finals.');
      expect(whereItsAt(nc, now: DateTime.utc(2026, 11, 3)), startsWith('After round 3 of 6. Round 4 is this week, starting Fri 6 Nov.'));
    });

    test('finished competitions name the winner', () {
      expect(whereItsAt(feed.byId('6n')!), 'Finished: won by ${feed.byId('6n')!.groups.first.rows.first.team}.');
      expect(whereItsAt(feed.byId('wxv')!), 'Finished.');
    });
  });
}
