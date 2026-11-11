import 'feeds.dart';
import 'format.dart';

/// The words on a shareable pick card, kept apart from the drawing so they can be tested
/// (test/share_card_test.dart). Before the game: the model's pick. After: the score, never the pick.
typedef ShareCardText = ({String kicker, String headline, String? figure, String matchup, String when});

ShareCardText shareCardText(Gender g, {Fixture? fixture, Result? result, String? zone}) {
  final w = g == Gender.women ? ' (women)' : '';
  if (result != null) {
    final r = result;
    final winner = r.winner;
    return (
      kicker: 'FULL TIME',
      headline: winner == null ? 'All square' : '$winner win',
      figure: '${r.homeScore}–${r.awayScore}',
      matchup: '${r.home} v ${r.away}$w',
      when: [dateLabel(r.date), if (r.comp.isNotEmpty) r.comp].join(' · '),
    );
  }
  final f = fixture!;
  final p = pickOf(f.home, f.away, f.pick);
  final k = f.kickOff?.toLocal();
  return (
    kicker: 'THE MODEL’S PICK',
    headline: p == null ? 'Too close to call' : p.team,
    figure: p == null ? null : '${p.pct}%',
    matchup: '${f.home} v ${f.away}$w',
    when: [
      if (k == null) dateLabel(f.date) else '${dayLabel(k)} · ${clock(k)} ${zone ?? k.timeZoneName}',
      if (f.comp.isNotEmpty) f.comp,
    ].join(' · '),
  );
}
