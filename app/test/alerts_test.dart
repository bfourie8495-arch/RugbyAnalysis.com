import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/alerts.dart';
import 'package:rugby_analysis/models/feeds.dart';

/// A small matchday feed: top 8 men's sides are A to H, and I is ranked 9th.
MatchdayFeed feed(List<Map<String, Object?>> fixtures) => MatchdayFeed.fromJson({
      'asOf': '2026-11-02',
      'nations': {},
      'm': {
        'ranked': [
          for (final (i, t) in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'].indexed) [t, i + 1, 90 - i]
        ],
        'fixtures': fixtures,
        'results': [],
        'form': {},
      },
      'w': {'ranked': [], 'fixtures': [], 'results': [], 'form': {}},
    });

Map<String, Object?> fx(String date, String h, String a, [String time = '15:00']) =>
    {'d': date, 'ko': '${date}T$time:00Z', 'h': h, 'a': a, 'c': 'Test', 'v': '', 'p': 0.5};

void main() {
  final now = DateTime(2026, 11, 2, 20); // a Monday evening
  final f = feed([
    fx('2026-11-06', 'A', 'B'), // Friday: big game
    fx('2026-11-07', 'C', 'I'), // Saturday: I isn't top 8
    fx('2026-11-07', 'I', 'H'),
    fx('2026-11-14', 'A', 'D'), // next weekend: big game
    fx('2026-10-31', 'A', 'C'), // already played
  ]);

  test('big games are top-8 v top-8', () {
    final w = worthWatching(f, {}, const AlertPrefs(), now: now);
    expect([for (final x in w) '${x.fixture.home}-${x.fixture.away}'], ['A-B', 'A-D']);
    expect(w.every((x) => x.reason == WatchReason.bigGame), isTrue);
  });

  test('a followed team counts, and wins over big game', () {
    final w = worthWatching(f, {followKey(Gender.men, 'I'), followKey(Gender.men, 'A')}, const AlertPrefs(), now: now);
    final byGame = {for (final x in w) '${x.fixture.home}-${x.fixture.away}': x};
    expect(byGame.keys, containsAll(['A-B', 'C-I', 'I-H', 'A-D']));
    expect(byGame['A-B']!.reason, WatchReason.yourTeam);
    expect(byGame['A-B']!.team, 'A');
    expect(byGame['C-I']!.team, 'I');
  });

  test('muted teams and switched-off big games drop out', () {
    final prefs = AlertPrefs(bigGames: false, muted: {followKey(Gender.men, 'I')});
    final w = worthWatching(f, {followKey(Gender.men, 'I')}, prefs, now: now);
    expect(w, isEmpty);
  });

  test('a one-off reminder counts', () {
    final target = f.men.fixtures.firstWhere((x) => x.home == 'C');
    final prefs = AlertPrefs(bigGames: false, reminders: {reminderKey(Gender.men, target)});
    final w = worthWatching(f, {}, prefs, now: now);
    expect(w.single.reason, WatchReason.reminder);
  });

  test('the weekend runs Thursday to Wednesday', () {
    expect(weekendStart(DateTime(2026, 11, 7)), DateTime(2026, 11, 5)); // Saturday -> Thursday
    expect(weekendStart(DateTime(2026, 11, 5)), DateTime(2026, 11, 5)); // Thursday itself
    expect(weekendStart(DateTime(2026, 11, 4)), DateTime(2026, 10, 29)); // Wednesday -> previous Thursday
  });

  test('the heads-up covers only the first weekend with games', () {
    final all = worthWatching(f, {followKey(Gender.men, 'I')}, const AlertPrefs(), now: now);
    final weekend = nextWeekend(all);
    expect(weekend.map((x) => x.fixture.date).toSet(), {'2026-11-06', '2026-11-07'});
    final text = headsUpText(weekend);
    expect(text.title, '3 games for you this weekend');
    expect(text.body.split('\n').length, 3);
  });

  test('one game gets a named title', () {
    final one = nextWeekend(worthWatching(f, {}, const AlertPrefs(), now: now));
    expect(headsUpText(one).title, 'A v B this weekend');
  });

  test('settings survive a round trip', () {
    final a = AlertPrefs(on: true, kickoffMinutes: 15, bigGamesFor: {Gender.women}, muted: {'m|A'}, reminders: {'m|2026-11-07|C|I'});
    final b = AlertPrefs.fromMap(a.toMap());
    expect(b.on, isTrue);
    expect(b.kickoffMinutes, 15);
    expect(b.bigGamesFor, {Gender.women});
    expect(b.muted, {'m|A'});
    expect(b.reminders, {'m|2026-11-07|C|I'});
  });
}
