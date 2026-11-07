import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/format.dart';

// The feeds in test/data are real copies of rugbyanalysis.com/app/*.json, so
// these tests check the app reads exactly what the website publishes.
Map<String, dynamic> readFeed(String name) => jsonDecode(File('test/data/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('flags', () {
    test('two-letter codes become regional-indicator flags', () {
      expect(flagEmoji('za'), '\u{1F1FF}\u{1F1E6}');
      expect(flagEmoji('NZ'), '\u{1F1F3}\u{1F1FF}');
    });

    test('England, Scotland and Wales use tag sequences', () {
      expect(flagEmoji('gb-eng'), '\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}');
      expect(flagEmoji('gb-wls').runes.length, 7);
    });

    test('no code, no flag', () => expect(flagEmoji(''), ''));
  });

  group('matchday feed', () {
    final feed = MatchdayFeed.fromJson(readFeed('matchday'));

    test('has rankings, fixtures with picks, results and form', () {
      expect(feed.men.ranked.first.position, 1);
      expect(feed.men.ranked.length, greaterThanOrEqualTo(20));
      expect(feed.women.ranked, isNotEmpty);
      expect(feed.men.fixtures, isNotEmpty);
      expect(feed.men.fixtures.where((f) => f.pick != null), isNotEmpty);
      expect(feed.men.results, isNotEmpty);
      expect(feed.men.form.values.every((f) => RegExp(r'^[WDL]{0,5}$').hasMatch(f)), isTrue);
    });

    test('fixtures are soonest first and kick-offs are UTC', () {
      final days = [for (final f in feed.men.fixtures) f.date];
      expect([...days]..sort(), days);
      expect(feed.men.fixtures.first.kickOff?.isUtc, isTrue);
    });

    test('every team in a fixture has a nation with a code', () {
      for (final f in feed.men.fixtures) {
        for (final t in [f.home, f.away]) {
          expect(feed.nation(t).code, isNotEmpty, reason: t);
        }
      }
      expect(feed.nation('South Africa').flag, flagEmoji('za'));
      expect(feed.nation('Nowhere FC').code, 'NOW');
    });

    test('every fixture has a head-to-head, turned round for whoever asks', () {
      for (final f in feed.men.fixtures) {
        final h = feed.men.meeting(f.home, f.away);
        if (h == null) continue; // they've never met
        expect(h.a, f.home);
        expect(h.record.length, 3);
        expect(h.played, greaterThan(0));
        expect(h.meetings.first.date.compareTo(h.meetings.last.date), greaterThanOrEqualTo(0), reason: 'newest first');
        final back = feed.men.meeting(f.away, f.home)!;
        expect(back.record, h.record.reversed.toList());
      }
      final sa = feed.men.meeting('South Africa', 'Italy')!;
      expect(sa.record[0], greaterThan(sa.record[2]));
    });

    test('team numbers and the latest results’ details', () {
      final sa = feed.men.stats['South Africa']!;
      expect(sa.allTime.length, 3);
      expect(sa.last.fold(0, (a, b) => a + b), sa.lastN);
      expect(sa.pointsFor, greaterThan(0));
      expect(sa.recent, isNotEmpty);
      expect(RegExp(r'^[WDL]\d+$').hasMatch(sa.streak), isTrue);
      final withDetail = feed.men.results.where((r) => r.detail?.hasScoring ?? false);
      expect(withDetail, isNotEmpty);
      for (final r in withDetail) {
        expect(r.detail!.home.tries! * 5, lessThanOrEqualTo(r.homeScore));
      }
    });
  });

  group('tournaments feed', () {
    final feed = TournamentsFeed.fromJson(readFeed('tournaments'));

    test('tournaments carry their numbers', () {
      final six = feed.byId('6n')!;
      final s = six.stats!;
      expect(s.games, six.groups.first.rows.fold(0, (a, r) => a + r.played) ~/ 2);
      expect(s.avgPoints, greaterThan(20));
      expect(s.biggest, isNotNull);
      expect(s.scorers, isNotEmpty);
      expect(six.scoring.every((x) => x.pointsFor > 0), isTrue);
    });

    test('has tables, series and a World Cup', () {
      expect(feed.tournaments, isNotEmpty);
      final six = feed.tournaments.firstWhere((t) => t.name == 'Six Nations');
      expect(six.groups.single.rows.length, 6);
      expect(six.groups.single.rows.first.pos, 1);
      expect(feed.tournaments.any((t) => t.isSeries && t.records.isNotEmpty), isTrue);
    });

    test('live tournaments come first', () {
      final men = feed.forGender(Gender.men);
      final firstDone = men.indexWhere((t) => t.status == TournamentStatus.done);
      expect(men.skip(firstDone).every((t) => t.status == TournamentStatus.done), isTrue);
    });

    test('the World Cup has six pools, 36 pool games and 16 knockouts', () {
      final wc = feed.worldCup;
      expect(wc.pools.length, 6);
      expect(wc.pools.values.every((p) => p.length == 4), isTrue);
      expect(wc.matches.length, 36);
      expect(wc.knockouts.length, 16);
      expect(wc.poolOf('South Africa'), 'B');
      expect(wc.firstMatchOf('South Africa')!.involves('Italy'), isTrue);
      expect(wc.knockout('Final')!.city, 'Sydney');
      // 18:45 in Perth on 1 October 2027 is 10:45 UTC
      expect(wc.firstKickOff, DateTime.utc(2027, 10, 1, 10, 45));
    });

    test('World Cup predictions add up', () {
      final wc = feed.worldCup;
      final total = wc.titleChances.fold<double>(0, (a, b) => a + b.pct);
      expect(total, closeTo(100, 1));
      final sa = wc.teamSims['South Africa']!;
      expect(sa.pool, 'B');
      expect(sa.reach['QF']!, lessThanOrEqualTo(sa.reach['R16']!));
      expect(sa.win, lessThanOrEqualTo(sa.reach['Final']!));
      expect(sa.scenarios.map((s) => s.key), contains('1'));
      expect(sa.scenarios.first.stages.first.opponents, isNotEmpty);
    });

    test('a nation knows its tournaments', () {
      final entries = feed.entriesFor(Gender.men, 'France');
      expect(entries.map((e) => e.id), contains('6n'));
      final six = entries.firstWhere((e) => e.id == '6n');
      expect(six.pos, inInclusiveRange(1, 6));
    });

    test('the women’s World Cup lists who has qualified', () {
      final w = feed.womensWorldCup;
      expect(w.teams, 16);
      expect(w.qualified.map((q) => q.team), containsAll(['Australia', 'England']));
    });
  });

  group('format', () {
    test('chances', () {
      expect(pct(0), '0%');
      expect(pct(0.4), '<1%');
      expect(pct(28.14), '28%');
      expect(pct(99.7), '>99%');
      expect(pct(100), '100%');
    });

    test('ordinals', () {
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(ordinal).toList(), ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd']);
    });

    test('dates and picks', () {
      expect(dateLabel('2026-11-07'), 'Sat 7 Nov');
      expect(shortDate('2026-11-07'), '7 Nov 26');
      expect(clock(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(pickOf('Ireland', 'Argentina', 0.77), (team: 'Ireland', pct: 77));
      expect(pickOf('Italy', 'South Africa', 0.13), (team: 'South Africa', pct: 87));
      expect(pickOf('A', 'B', null), isNull);
      expect(daysUntil(DateTime(2027, 10, 1, 11), now: DateTime(2026, 10, 30, 8)), 336);
    });

    test('kick-off times with and without seconds', () {
      expect(parseKickOff('2027-10-01T10:45Z'), DateTime.utc(2027, 10, 1, 10, 45));
      expect(parseKickOff('2026-11-07T14:10:00Z'), DateTime.utc(2026, 11, 7, 14, 10));
      expect(parseKickOff(null), isNull);
    });
  });
}
