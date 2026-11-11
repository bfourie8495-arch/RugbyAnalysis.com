import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/format.dart';
import 'package:rugby_analysis/models/site_links.dart';

void main() {
  group('Website slugs match pipeline/build.py', () {
    test('known cases', () {
      expect(siteSlug('South Africa'), 'south-africa');
      expect(siteSlug('New Zealand'), 'new-zealand');
      expect(siteSlug('Curaçao'), 'curacao');
      expect(siteSlug('Réunion'), 'reunion');
      expect(siteSlug("Cote D'Ivoire"), 'cote-d-ivoire');
      expect(siteSlug('Trinidad & Tobago'), 'trinidad-tobago');
      expect(siteSlug(' USA '), 'usa');
    });

    test('every nation playing in the feed has a page on the site', () {
      // The site's nations: the top ten plus pipeline/others.json, slugged by build.py's rule.
      const top10 = ['Argentina', 'Australia', 'England', 'France', 'Ireland', 'Italy', 'New Zealand', 'Scotland', 'South Africa', 'Wales'];
      final others = (jsonDecode(File('../pipeline/others.json').readAsStringSync()) as Map<String, dynamic>).keys;
      final site = {for (final n in [...top10, ...others]) siteSlug(n)};
      final feed = jsonDecode(File('test/data/matchday.json').readAsStringSync()) as Map<String, dynamic>;
      for (final g in ['m', 'w']) {
        final side = feed[g] as Map<String, dynamic>;
        for (final f in [...side['fixtures'] as List, ...side['results'] as List]) {
          for (final team in [f['h'], f['a']]) {
            expect(site, contains(siteSlug(team as String)), reason: '$g: $team has no page on the website');
          }
        }
      }
    });
  });

  group('Links to the website', () {
    test('ref goes before the #, so the site still finds the page', () {
      expect(siteTeamUrl(Gender.men, 'South Africa'), 'https://rugbyanalysis.com/?ref=app#south-africa');
      expect(siteH2hUrl(Gender.men, 'France', 'South Africa'), 'https://rugbyanalysis.com/?ref=app#h2h/france-v-south-africa');
      expect(siteH2hUrl(Gender.women, 'England', 'New Zealand', ref: 'share'),
          'https://rugbyanalysis.com/?ref=share#women/h2h/england-v-new-zealand');
      expect(siteTeamUrl(Gender.women, 'Canada'), 'https://rugbyanalysis.com/?ref=app#women/canada');
    });
  });

  group('Share text', () {
    final ko = DateTime.utc(2026, 11, 13, 20, 10);
    final local = ko.toLocal();
    final when = '${dayLabel(local)}, ${clock(local)} GMT';

    test('before the game: fixture, kick-off with its zone, the pick and the link', () {
      final f = Fixture(date: '2026-11-13', home: 'France', away: 'South Africa', kickOff: ko, pick: 0.41);
      expect(shareText(Gender.men, fixture: f, zone: 'GMT'),
          'France v South Africa, $when. The model picks South Africa (59%).\n'
          'https://rugbyanalysis.com/?ref=share#h2h/france-v-south-africa');
    });

    test('no pick, no kick-off time: says what it knows', () {
      final f = Fixture(date: '2026-11-14', home: 'Spain', away: 'Canada');
      expect(shareText(Gender.women, fixture: f),
          'Spain v Canada (women), Sat 14 Nov.\nhttps://rugbyanalysis.com/?ref=share#women/h2h/spain-v-canada');
    });

    test('after the result: the score only, never the pick', () {
      final r = Result(date: '2026-11-13', home: 'France', away: 'South Africa', homeScore: 20, awayScore: 27, winnerChance: 59);
      final t = shareText(Gender.men, result: r);
      expect(t, 'Full time: France 20–27 South Africa.\nHead to head: https://rugbyanalysis.com/?ref=share#h2h/france-v-south-africa');
      expect(t, isNot(contains('pick')));
    });
  });
}
