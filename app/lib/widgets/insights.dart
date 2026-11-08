// The talking points: upsets, a team's season against who it played, its scoring trend, records at a ground
// and with a referee, what the latest results did to the title race, and the leading try scorers.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'stats.dart';

const _small = TextStyle(fontSize: 12, color: RaColors.faint);

String _wdl(List<int> x) => x.length < 3 ? '' : '${x[0]}–${x[1]}–${x[2]}';
int _played(List<int> x) => x.fold(0, (a, b) => a + b);
String _rate(List<int> x) => _played(x) == 0 ? '' : '${(100 * x[0] / _played(x)).round()}%';

/// A small gold 'UPSET' tag for a result the winner was given less than a 40% chance of.
class UpsetTag extends StatelessWidget {
  const UpsetTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: RaColors.gold, borderRadius: BorderRadius.circular(6)),
        child: const Text('UPSET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: RaColors.onGold, letterSpacing: 0.6)),
      );
}

/// One line on how surprising a result was: 'Upset: Australia had a 26% chance' or 'South Africa were 84% favourites'.
class UpsetLine extends StatelessWidget {
  const UpsetLine({super.key, required this.result});

  final Result result;

  @override
  Widget build(BuildContext context) {
    final r = result, w = r.winner, c = r.winnerChance;
    if (w == null || c == null) return const SizedBox.shrink();
    final upset = r.isUpset;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: upset ? RaColors.gold.withValues(alpha: 0.14) : RaColors.cardHi,
        borderRadius: BorderRadius.circular(12),
        border: upset ? Border.all(color: RaColors.gold) : null,
      ),
      child: Row(children: [
        Icon(upset ? Icons.bolt : Icons.check_circle_outline, color: upset ? RaColors.gold : RaColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(TextSpan(children: [
            if (upset) const TextSpan(text: 'Upset! ', style: TextStyle(fontWeight: FontWeight.w800, color: RaColors.gold)),
            TextSpan(
                text: upset
                    ? '$w had a $c% chance beforehand.'
                    : c >= 75
                        ? '$w were big favourites ($c%) and delivered.'
                        : '$w were favourites ($c%) and won.'),
          ])),
        ),
      ]),
    );
  }
}

/// Both teams' records at the ground, and (for a result) with the referee.
class GroundAndRefereeSection extends StatelessWidget {
  const GroundAndRefereeSection({super.key, required this.gender, required this.home, required this.away, this.ground, this.referee, this.past = false});

  final Gender gender;
  final String home;
  final String away;
  final PairRecord? ground;
  final PairRecord? referee;
  final bool past; // a result: the records as they stood before it

  @override
  Widget build(BuildContext context) {
    final feed = AppScope.of(context).matchday!;
    Widget block(String title, PairRecord p) => RaCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final (t, x) in [(home, p.home), (away, p.away)])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  TeamBadge(feed.nation(t), size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (_played(x) == 0)
                    const Text('First time', style: TextStyle(color: RaColors.muted))
                  else ...[
                    Text(_wdl(x), style: displayStyle(15)),
                    const SizedBox(width: 10),
                    SizedBox(width: 44, child: Text(_rate(x), textAlign: TextAlign.right, style: const TextStyle(color: RaColors.gold, fontWeight: FontWeight.w800))),
                  ],
                ]),
              ),
            Text(past ? 'Won–drawn–lost before this Test, and win rate.' : 'Won–drawn–lost, and win rate.', style: _small),
          ]),
        );
    final g = ground, r = referee;
    if (g == null && r == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Ground and referee'),
      if (g != null) block('At ${g.name}', g),
      if (g != null && r != null) const SizedBox(height: 10),
      if (r != null) block('With ${r.name} refereeing', r),
    ]);
  }
}

/// The last twelve months Test by Test: each opponent's world ranking now, the score, and the team's chance
/// beforehand, so a win over the No. 3 stands out from one over the No. 15.
class SeasonSection extends StatelessWidget {
  const SeasonSection({super.key, required this.gender, required this.team, required this.stats});

  final Gender gender;
  final String team;
  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    final feed = AppScope.of(context).matchday!;
    final side = feed.side(gender);
    final games = stats.season;
    if (games.isEmpty) return const SizedBox.shrink();
    final top10 = [for (final g in games) if ((side.rankOf(g.opponent) ?? 99) <= 10) g];
    final rec = [
      top10.where((g) => g.score > g.against).length,
      top10.where((g) => g.score == g.against).length,
      top10.where((g) => g.score < g.against).length,
    ];
    final beatOdds = games.where((g) => g.score > g.against && g.chance < 50).length;
    final slipped = games.where((g) => g.score < g.against && g.chance > 50).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Season so far', note: 'Last 12 months'),
      RaCard(
        child: Row(children: [
          Expanded(child: _Fact(big: top10.isEmpty ? '–' : _wdl(rec), label: 'v top-10 sides')),
          Expanded(child: _Fact(big: '$beatOdds', label: beatOdds == 1 ? 'win as underdogs' : 'wins as underdogs')),
          Expanded(child: _Fact(big: '$slipped', label: slipped == 1 ? 'defeat as favourites' : 'defeats as favourites')),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(children: [
            for (final (i, g) in games.reversed.indexed) ...[
              if (i > 0) const Divider(height: 1),
              InkWell(
                onTap: () => openResult(
                    context,
                    gender,
                    g.where == 'a'
                        ? Result(date: g.date, home: g.opponent, away: team, homeScore: g.against, awayScore: g.score)
                        : Result(date: g.date, home: team, away: g.opponent, homeScore: g.score, awayScore: g.against)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 50, child: Text(shortDate(g.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RaColors.faint))),
                      TeamBadge(feed.nation(g.opponent), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${g.where == 'a' ? 'at' : 'v'} ${g.opponent}',
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            [
                              if (side.rankOf(g.opponent) != null) 'World No. ${side.rankOf(g.opponent)}',
                              'given ${g.chance}%',
                            ].join(' · '),
                            style: _small,
                          ),
                        ]),
                      ),
                      _ResultChip(score: g.score, against: g.against, oddsBeaten: (g.score > g.against && g.chance < 50) || (g.score < g.against && g.chance > 50)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('Rankings are today’s. “Given” is the team’s chance beforehand. Gold: against the odds.', style: _small),
      ),
    ]);
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.score, required this.against, required this.oddsBeaten});

  final int score;
  final int against;
  final bool oddsBeaten;

  @override
  Widget build(BuildContext context) {
    final won = score > against, drew = score == against;
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: oddsBeaten ? RaColors.gold.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: oddsBeaten ? Border.all(color: RaColors.gold) : null,
      ),
      child: Column(children: [
        Text('$score–$against', style: displayStyle(15)),
        Text(won ? 'WON' : drew ? 'DRAW' : 'LOST',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: won ? RaColors.gold : RaColors.muted, letterSpacing: 0.6)),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.big, required this.label});

  final String big;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(big, style: displayStyle(20, color: RaColors.gold, weight: FontWeight.w800)),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
      ]);
}

/// Points scored (gold, up) and conceded (blue, down) over the last twenty Tests, oldest on the left, with the
/// record in close games underneath.
class TrendSection extends StatelessWidget {
  const TrendSection({super.key, required this.stats});

  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    final t = stats.trend;
    if (t.length < 4) return const SizedBox.shrink();
    final c = stats.close;
    final firstHalf = t.take(t.length ~/ 2), secondHalf = t.skip(t.length ~/ 2);
    double avgMargin(Iterable<({int scored, int conceded})> xs) => xs.isEmpty ? 0 : xs.map((x) => x.scored - x.conceded).reduce((a, b) => a + b) / xs.length;
    final shift = avgMargin(secondHalf) - avgMargin(firstHalf);
    final direction = shift.abs() < 3
        ? 'Steady: the average margin is about the same as ${t.length ~/ 2} Tests ago.'
        : shift > 0
            ? 'On the up: winning by ${shift.round()} points a game more than in the ${t.length ~/ 2} Tests before.'
            : 'Dipping: ${(-shift).round()} points a game worse than in the ${t.length ~/ 2} Tests before.';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Scoring trend', note: 'Last ${t.length} Tests'),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            label: 'Bar chart of points scored and conceded in each of the last ${t.length} Tests',
            child: SizedBox(height: 140, child: CustomPaint(painter: _TrendPainter(t))),
          ),
          const SizedBox(height: 6),
          const Row(children: [
            _Key(colour: RaColors.gold, label: 'Scored'),
            SizedBox(width: 14),
            _Key(colour: RaColors.away, label: 'Conceded'),
            Spacer(),
            Text('Oldest → newest', style: _small),
          ]),
          const Divider(height: 22),
          Text(direction, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (c.length == 3 && _played(c) > 0) ...[
            const SizedBox(height: 6),
            Text('Close games (decided by 7 or fewer) over three years: ${_wdl(c)}, won ${_rate(c)}.', style: const TextStyle(color: RaColors.muted)),
          ],
        ]),
      ),
    ]);
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: _small),
      ]);
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.games);

  final List<({int scored, int conceded})> games;

  @override
  void paint(Canvas canvas, Size size) {
    final top = games.map((g) => math.max(g.scored, g.conceded)).fold<int>(1, (a, b) => math.max(a, b)).toDouble();
    final mid = size.height / 2;
    final slot = size.width / games.length;
    final w = math.max(2.0, slot * 0.6);
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), Paint()..color = RaColors.line2);
    for (var i = 0; i < games.length; i++) {
      final g = games[i];
      final x = i * slot + (slot - w) / 2;
      final up = (g.scored / top) * (mid - 4), down = (g.conceded / top) * (mid - 4);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, mid - up, w, up), const Radius.circular(2)),
          Paint()..color = g.scored > g.conceded ? RaColors.gold : RaColors.gold.withValues(alpha: 0.45));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, mid + 1, w, down), const Radius.circular(2)),
          Paint()..color = g.conceded > g.scored ? RaColors.away : RaColors.away.withValues(alpha: 0.45));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.games != games;
}

/// What the latest results did to each team's chance of winning the tournament, before → after.
class TitleMovesSection extends StatelessWidget {
  const TitleMovesSection({super.key, required this.tournament, this.title = 'What the latest results did'});

  final Tournament tournament;
  final String title;

  @override
  Widget build(BuildContext context) {
    final m = tournament.moves;
    if (m == null || m.changes.isEmpty) return const SizedBox.shrink();
    final feed = AppScope.of(context).matchday!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title, note: 'Chance of the title'),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in m.results)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: RaColors.cardHi, borderRadius: BorderRadius.circular(8)),
                child: Text('${feed.nation(r.home).code} ${r.homeScore}–${r.awayScore} ${feed.nation(r.away).code}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          for (final c in m.changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                TeamBadge(feed.nation(c.team), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(c.team, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${pct(c.before)} → ', style: const TextStyle(color: RaColors.muted)),
                Text(pct(c.after), style: displayStyle(15)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 58,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Icon((c.after - c.before).abs() < 0.5 ? Icons.remove : c.after > c.before ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14, color: c.after > c.before ? RaColors.gold : RaColors.away),
                    Text((c.after - c.before).abs().toStringAsFixed((c.after - c.before).abs() >= 10 ? 0 : 1),
                        style: TextStyle(fontWeight: FontWeight.w800, color: c.after > c.before ? RaColors.gold : RaColors.away)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          const Text('From 20,000 simulations of the rest of the tournament, before and after these results.', style: _small),
        ]),
      ),
    ]);
  }
}

/// The leading try scorers in all Tests over the last twelve months.
class HotScorersSection extends StatelessWidget {
  const HotScorersSection({super.key, required this.gender, this.limit = 15});

  final Gender gender;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final feed = AppScope.of(context).matchday!;
    final side = feed.side(gender);
    if (side.hot.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Who’s scoring', note: 'Tries, last 12 months'),
      Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, h) in side.hot.take(limit).indexed)
            Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: RaColors.line))),
              child: Row(children: [
                SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(color: RaColors.faint, fontWeight: FontWeight.w700))),
                TeamBadge(feed.nation(h.team), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(h.player, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${h.team} · in ${h.tests} ${h.tests == 1 ? 'Test' : 'Tests'}', style: _small),
                  ]),
                ),
                Text('${h.tries}', style: displayStyle(18, color: RaColors.gold, weight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
      if (side.hotOf > side.hotFrom)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('From the ${side.hotFrom} of ${side.hotOf} Tests whose try scorers are recorded.', style: _small),
        ),
    ]);
  }
}

/// The year's biggest upsets, biggest first.
class UpsetsSection extends StatelessWidget {
  const UpsetsSection({super.key, required this.gender, this.limit = 10});

  final Gender gender;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final side = AppScope.of(context).matchday!.side(gender);
    if (side.upsets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Upsets of the year', note: 'Winner’s chance beforehand'),
      Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(children: [
            for (final (i, u) in side.upsets.take(limit).indexed) ...[
              if (i > 0) const Divider(height: 1),
              MeetingRow(gender: gender, result: u, note: '${u.winnerChance}%'),
            ],
          ]),
        ),
      ),
    ]);
  }
}
