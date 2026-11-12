import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/models/format.dart';
import 'package:rugby_analysis/models/share_card.dart';

void main() {
  test('before the game: the model’s pick, its chance, and when', () {
    final ko = DateTime.utc(2026, 11, 13, 20, 10);
    final f = Fixture(date: '2026-11-13', home: 'France', away: 'South Africa', kickOff: ko, pick: 0.41, comp: 'Nations Championship');
    final t = shareCardText(Gender.men, fixture: f, zone: 'GMT');
    expect(t.kicker, 'THE MODEL’S PICK');
    expect(t.headline, 'South Africa');
    expect(t.figure, '59%');
    expect(t.matchup, 'France v South Africa');
    expect(t.when, '${dayLabel(ko.toLocal())} · ${clock(ko.toLocal())} GMT · Nations Championship');
  });

  test('no pick yet: says so, with no number', () {
    final t = shareCardText(Gender.women, fixture: Fixture(date: '2026-11-14', home: 'Spain', away: 'Canada'));
    expect(t.headline, 'Too close to call');
    expect(t.figure, isNull);
    expect(t.matchup, 'Spain v Canada (women)');
  });

  test('after the game: the score, never the pick', () {
    final r = Result(date: '2026-11-13', home: 'France', away: 'South Africa', homeScore: 20, awayScore: 27, winnerChance: 59);
    final t = shareCardText(Gender.men, result: r);
    expect(t.kicker, 'FULL TIME');
    expect(t.headline, 'South Africa win');
    expect(t.figure, '20–27');
    final d = shareCardText(Gender.men, result: Result(date: '2026-11-13', home: 'Fiji', away: 'Japan', homeScore: 20, awayScore: 20));
    expect(d.headline, 'All square');
  });
}
