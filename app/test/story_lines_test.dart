import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/clubs.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/story_lines.dart';
import 'package:rugby_analysis/widgets/stats.dart' show streakTile;

ClubsFeed _clubs() => ClubsFeed.fromJson(jsonDecode(File('test/data/clubs.json').readAsStringSync()) as Map<String, dynamic>);

({String player, String team, int tries, int tests}) _h(String p, int t) => (player: p, team: 'France', tries: t, tests: 5);

void main() {
  group('Talking points titles', () {
    test('the biggest upset names the winner and their chance', () {
      final u = Result(date: '2026-07-04', home: 'Fiji', away: 'Wales', homeScore: 24, awayScore: 39, winnerChance: 22);
      expect(upsetsTitle([u]), 'Wales at 22%: the year’s biggest upset');
      expect(upsetsTitle([]), 'Upsets of the year');
    });

    test('the try-scoring lead, alone or shared', () {
      expect(scorersTitle([_h('Bielle-Biarrey', 11), _h('Jordan', 11), _h('Myszka', 8)]), 'Bielle-Biarrey and Jordan lead with 11 tries');
      expect(scorersTitle([_h('Jordan', 9), _h('Myszka', 8)]), 'Jordan leads with 9 tries');
      expect(scorersTitle([_h('A', 5), _h('B', 5), _h('C', 5)]), 'Three players share the lead on 5 tries');
      expect(scorersTitle([]), 'Who’s scoring');
    });

    test('the scoring trend says which way it is going', () {
      expect(trendTitle(-9.4), 'Down 9 points a game');
      expect(trendTitle(6.2), 'Up 6 points a game');
      expect(trendTitle(2.9), 'Holding steady');
      expect(trendSentence(-9.4, 10), '9 points a game worse than in the 10 Tests before.');
    });

    test('a run of two or more becomes a tile', () {
      expect(streakTile('W3'), (big: '3', label: 'wins in a row'));
      expect(streakTile('L2'), (big: '2', label: 'defeats in a row'));
      expect(streakTile('W1'), isNull);
      expect(streakTile(''), isNull);
    });
  });

  group('Club opening sentences', () {
    final feed = _clubs();
    String name(String id) => feed.club(id).name;

    test('a competition: who leads, by how much, and any perfect record', () {
      // URC in the test copy: Glasgow 19 from 5, Edinburgh 17 from 4 and won all four.
      expect(leagueIdea(feed.league('URC')!, name),
          'Glasgow Warriors top the table, 2 points clear of Edinburgh, who have a game in hand and are the only side to have won all four.');
      expect(leagueIdea(feed.league('PREM')!, name), startsWith('Leicester Tigers top the table, 4 points clear of Gloucester'));
    });

    test('no sentence for a cup or a season with no games yet', () {
      expect(leagueIdea(feed.league('ECC')!, name), isNull);
      expect(leagueIdea(feed.league('PWR')!, name), isNull);
    });

    test('a club: where they stand and their last five', () {
      expect(clubIdea(feed.club('glasgow'), feed.league('URC')),
          'Glasgow Warriors top the URC on 19 points from 5 matches, and have won 4 of their last 5.');
      expect(clubIdea(feed.club('edinburgh'), feed.league('URC')), startsWith('Edinburgh are 2nd in the URC on 17 points from 4 matches'));
    });
  });
}
