import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/chat.dart';
import 'package:rugby_analysis/models/clubs.dart';
import 'package:rugby_analysis/models/feeds.dart';

ClubsFeed _feed() => ClubsFeed.fromJson(jsonDecode(File('test/data/clubs.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  group('Clubs feed', () {
    final feed = _feed();

    test('has the ten competitions, like the website', () {
      expect(feed.leagues.map((l) => l.code), ['URC', 'PREM', 'PWR', 'T14', 'SR', 'CC', 'NPC', 'JL1', 'ECC', 'EPC']);
      expect(feed.league('PWR')!.gender, Gender.women);
      expect(feed.league('ECC')!.isCup, isTrue);
      expect(feed.league('ECC')!.table, isEmpty);
    });

    test('leagues have tables and every club in them is known', () {
      for (final l in feed.leagues.where((l) => !l.isCup)) {
        expect(l.table, isNotEmpty, reason: l.code);
        for (final r in l.table) {
          expect(feed.clubs, contains(r.club), reason: '${l.code}: ${r.club}');
          expect(r.won + r.drawn + r.lost, r.played);
        }
      }
      for (final l in feed.leagues) {
        for (final g in [...l.results, ...l.fixtures]) {
          expect(feed.clubs, contains(g.home));
          expect(feed.clubs, contains(g.away));
        }
      }
    });

    test('fixtures are unplayed with UTC kick-offs, results are played', () {
      for (final l in feed.leagues) {
        for (final f in l.fixtures) {
          expect(f.played, isFalse);
          if (f.kickOff != null) expect(f.kickOff!.isUtc, isTrue);
          expect(f.venue.toUpperCase(), isNot(anyOf('TBC', 'TBA')));
        }
        for (final r in l.results) {
          expect(r.played, isTrue);
        }
      }
    });

    test('a club knows its form and its result in each game', () {
      final glasgow = feed.club('glasgow');
      expect(glasgow.name, 'Glasgow Warriors');
      expect(glasgow.form, matches(RegExp(r'^[WDL]{1,5}$')));
      for (final g in glasgow.results) {
        expect(g.involves('glasgow'), isTrue);
        expect(['W', 'D', 'L'], contains(g.resultFor('glasgow')));
        expect(g.comp, isNotEmpty);
      }
      expect(feed.league('URC')!.positionOf('glasgow'), isNotNull);
      expect(feed.club('nobody').name, 'nobody');
    });
  });

  group('Chat', () {
    test('room codes are 12 easy-to-read characters', () {
      final r = Random(1);
      for (var i = 0; i < 50; i++) {
        final c = newRoomCode(r);
        expect(c, matches(RegExp(r'^[A-HJ-NP-Z2-9]{12}$')));
        expect(parseRoomCode(c), c);
      }
    });

    test('a code is found in a link, a message or typed with dashes', () {
      expect(parseRoomCode('abcd-efgh-jkmn'), 'ABCDEFGHJKMN');
      expect(parseRoomCode(' ABCD EFGH JKMN '), 'ABCDEFGHJKMN');
      expect(parseRoomCode('Tap to join: https://rugbyanalysis.com/join/ABCDEFGHJKMN\n(Or ...)'), 'ABCDEFGHJKMN');
      expect(parseRoomCode('ABCDEFGHJKM'), isNull); // too short
      expect(parseRoomCode('ABCDEFGHJKM0'), isNull); // 0 isn't used
      expect(spacedCode('ABCDEFGHJKMN'), 'ABCD-EFGH-JKMN');
      expect(inviteLink('ABCDEFGHJKMN'), 'https://rugbyanalysis.com/join/ABCDEFGHJKMN');
    });

    test('invite routes open the join screen', () {
      expect(joinCodeFromRoute('/join/ABCDEFGHJKMN'), 'ABCDEFGHJKMN');
      expect(joinCodeFromRoute('rugbyanalysis://app/join/abcdefghjkmn'), 'ABCDEFGHJKMN');
      expect(joinCodeFromRoute('/join/ABCDEFGHJKMN?x=1'), 'ABCDEFGHJKMN');
      expect(joinCodeFromRoute('/'), isNull);
      expect(joinCodeFromRoute(null), isNull);
    });

    test('names are tidied and kept short', () {
      expect(cleanName('  Brendon   F '), 'Brendon F');
      expect(cleanName('   '), isNull);
      expect(cleanName('x' * 30), isNull);
    });

    test('a pinned match survives the trip through Firestore', () {
      final f = Fixture(date: '2026-11-13', home: 'France', away: 'South Africa', kickOff: DateTime.utc(2026, 11, 13, 20, 10), comp: 'Nations Championship');
      final m = PinnedMatch.test(Gender.men, f);
      final back = PinnedMatch.fromMap(jsonDecode(jsonEncode(m.toMap())));
      expect(back, m);
      expect(back!.kickOff, DateTime.utc(2026, 11, 13, 20, 10));
      expect(back.gender, Gender.men);
      expect(PinnedMatch.fromMap({'k': 'x', 'h': 'a', 'a': 'b'}), isNull);
    });

    test('rooms say who is in them and sort by latest message', () {
      Room room(String id, List<String> members, {DateTime? at}) =>
          Room(id: id, name: id, ownerUid: 'me', members: members, names: const {'me': 'Me', 'a': 'Tom', 'b': 'Sipho', 'c': 'Ana', 'd': 'Jo'}, lastAt: at);
      expect(room('x', ['me']).peopleLine('me'), 'Just you so far');
      expect(room('x', ['me', 'a']).peopleLine('me'), 'You and Tom');
      expect(room('x', ['me', 'a', 'b', 'c']).peopleLine('me'), 'You, Tom, Sipho and Ana');
      expect(room('x', ['me', 'a', 'b', 'c', 'd']).peopleLine('me'), 'You and 4 others');
      final sorted = sortRooms([
        room('old', ['me'], at: DateTime(2026, 11, 1)),
        room('new', ['me'], at: DateTime(2026, 11, 8)),
        room('empty', ['me']),
      ]);
      expect(sorted.map((r) => r.id), ['empty', 'new', 'old']);
    });

    test('message times read naturally', () {
      final now = DateTime(2026, 11, 9, 15, 0);
      expect(chatTime(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(chatTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min');
      expect(chatTime(DateTime(2026, 11, 9, 9, 5), now: now), '09:05');
      expect(chatTime(DateTime(2026, 11, 8, 22, 0), now: now), 'Yesterday');
      expect(chatTime(DateTime(2026, 11, 7, 12, 0), now: now), 'Sat 7 Nov');
    });
  });
}
