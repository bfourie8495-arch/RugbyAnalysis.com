// The numbers behind a match, a team and a tournament: head-to-heads, side-by-side comparisons,
// a finished Test's tries, kicks and cards, and a team's record. Gold is always the first team
// (the home side on a match), blue the second, as on the pick bar.
import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../screens/match_screen.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'common.dart';

const _small = TextStyle(fontSize: 12, color: RaColors.faint);

String _num(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);

/// Three numbers as one bar: first team's share in gold, draws in grey, second team's in blue.
class SplitBar extends StatelessWidget {
  const SplitBar(this.values, {super.key, this.height = 10});

  final List<int> values; // first, draws, second
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = values.fold(0, (a, b) => a + b);
    const colours = [RaColors.gold, Color(0xFF3A4A66), RaColors.away];
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: total == 0
            ? Container(color: RaColors.track)
            : Row(children: [
                for (var i = 0; i < 3; i++)
                  if (values[i] > 0) Expanded(flex: values[i], child: Container(color: colours[i])),
              ]),
      ),
    );
  }
}

/// One line of a side-by-side comparison: 'Points a game  37.9 ▮▮▮▯ 21.2'. The better side is in bold;
/// [lowerIsBetter] for things like points conceded.
class CompareRow extends StatelessWidget {
  const CompareRow({super.key, required this.label, required this.first, required this.second, this.lowerIsBetter = false, this.format});

  final String label;
  final double? first;
  final double? second;
  final bool lowerIsBetter;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final f = format ?? _num;
    final a = first, b = second;
    final known = a != null && b != null;
    final aBetter = known && (lowerIsBetter ? a < b : a > b);
    final bBetter = known && (lowerIsBetter ? b < a : b > a);
    final total = known ? a + b : 0.0;
    TextStyle style(bool better, Color c) =>
        displayStyle(15, color: better ? c : RaColors.ink, weight: better ? FontWeight.w800 : FontWeight.w600);
    return Semantics(
      label: '$label: ${a == null ? 'not known' : f(a)} against ${b == null ? 'not known' : f(b)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Row(children: [
            SizedBox(width: 56, child: Text(a == null ? '–' : f(a), style: style(aBetter, RaColors.gold))),
            Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: RaColors.muted))),
            SizedBox(width: 56, child: Text(b == null ? '–' : f(b), textAlign: TextAlign.right, style: style(bBetter, RaColors.away))),
          ]),
          if (known && total > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Row(children: [
                  Expanded(flex: (1000 * a / total).round().clamp(1, 999), child: Container(color: aBetter ? RaColors.gold : RaColors.gold.withValues(alpha: 0.45))),
                  const SizedBox(width: 2),
                  Expanded(flex: (1000 * b / total).round().clamp(1, 999), child: Container(color: bBetter ? RaColors.away : RaColors.away.withValues(alpha: 0.45))),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Opens the match screen for a past Test (with its full record when it's among the latest results).
void openResult(BuildContext context, Gender gender, Result r) {
  final full = AppScope.read(context).matchday?.side(gender).resultFor(r) ?? r;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen.result(gender: gender, result: full)));
}

/// A past meeting as a compact row: date, the two teams, the score, the winner in bold.
class MeetingRow extends StatelessWidget {
  const MeetingRow({super.key, required this.gender, required this.result, this.note});

  final Gender gender;
  final Result result;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final w = r.winner;
    TextStyle team(String t) => TextStyle(fontWeight: w == t ? FontWeight.w800 : FontWeight.w500, color: w != null && w != t ? RaColors.muted : RaColors.ink);
    return InkWell(
      onTap: () => openResult(context, gender, r),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 66,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shortDate(r.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RaColors.faint)),
                if (note != null) Text(note!, style: const TextStyle(fontSize: 10, color: RaColors.gold, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: [TextSpan(text: r.home, style: team(r.home)), const TextSpan(text: ' v '), TextSpan(text: r.away, style: team(r.away))]),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text('${r.homeScore}–${r.awayScore}', style: displayStyle(15)),
          ]),
        ),
      ),
    );
  }
}

/// Every Test between two nations: the record, the last ten, typical score, biggest wins and the latest meetings.
class HeadToHeadSection extends StatelessWidget {
  const HeadToHeadSection({super.key, required this.gender, required this.first, required this.second, this.skip});

  final Gender gender;
  final String first;
  final String second;
  final Result? skip; // a result already shown above (the match itself)

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final h = feed.side(gender).meeting(first, second);
    if (h == null || h.played == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Head to head'),
        RaCard(child: Text('$first and $second have never met in a Test.', style: const TextStyle(color: RaColors.muted))),
      ]);
    }
    final rec = h.record;
    Widget count(int n, String label, Color colour, CrossAxisAlignment align) => Column(crossAxisAlignment: align, children: [
          Text('$n', style: displayStyle(26, color: colour, weight: FontWeight.w800)),
          Text(label, style: _small, overflow: TextOverflow.ellipsis),
        ]);
    final meetings = [for (final m in h.meetings) if (skip == null || m.date != skip!.date) m].take(5).toList();
    final l10 = h.last10, n10 = l10.fold(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Head to head', note: '${h.played} Tests since ${h.first}'),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: count(rec[0], '$first wins', RaColors.gold, CrossAxisAlignment.start)),
            count(rec[1], rec[1] == 1 ? 'draw' : 'draws', RaColors.ink, CrossAxisAlignment.center),
            Expanded(child: count(rec[2], '$second wins', RaColors.away, CrossAxisAlignment.end)),
          ]),
          const SizedBox(height: 10),
          SplitBar(rec),
          if (h.played > n10 && n10 > 0) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Text('Last 10 meetings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Text('${l10[0]}–${l10[1]}–${l10[2]}', style: displayStyle(14)),
            ]),
            const SizedBox(height: 6),
            SplitBar(l10, height: 6),
          ],
          const Divider(height: 24),
          CompareRow(label: n10 < h.played ? 'Average score, last $n10' : 'Average score', first: h.avg.isEmpty ? null : h.avg[0], second: h.avg.length < 2 ? null : h.avg[1]),
          for (final t in [first, second])
            if (h.biggest[t] case final b?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$t’s biggest win: ', style: const TextStyle(color: RaColors.muted)),
                  TextSpan(text: '${b.scoreOf(t)}–${b.scoreOf(t == b.home ? b.away : b.home)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: ' in ${b.date.substring(0, 4)}', style: const TextStyle(color: RaColors.muted)),
                ]), style: const TextStyle(fontSize: 13)),
              ),
        ]),
      ),
      if (meetings.isNotEmpty) ...[
        const SizedBox(height: 10),
        _Tiles([for (final m in meetings) MeetingRow(gender: gender, result: m)]),
      ],
    ]);
  }
}

/// Both teams side by side over their last ten Tests, then each team's latest results.
class FormNumbersSection extends StatelessWidget {
  const FormNumbersSection({super.key, required this.gender, required this.first, required this.second});

  final Gender gender;
  final String first;
  final String second;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final side = feed.side(gender);
    final a = side.stats[first], b = side.stats[second];
    double? pts(String t) {
      for (final r in side.ranked) {
        if (r.team == t) return r.points;
      }
      return null;
    }

    final children = <Widget>[];
    if (a != null || b != null) {
      children.addAll([
        const SectionTitle('By the numbers', note: 'Last 10 Tests each'),
        RaCard(
          child: Column(children: [
            Row(children: [
              TeamBadge(feed.nation(first), size: 24),
              const Spacer(),
              TeamBadge(feed.nation(second), size: 24),
            ]),
            const SizedBox(height: 4),
            CompareRow(label: 'Won', first: a == null ? null : a.last[0].toDouble(), second: b == null ? null : b.last[0].toDouble()),
            CompareRow(label: 'Points scored a game', first: a?.pointsFor, second: b?.pointsFor),
            CompareRow(label: 'Points conceded a game', first: a?.pointsAgainst, second: b?.pointsAgainst, lowerIsBetter: true),
            if (a?.triesFor != null || b?.triesFor != null) ...[
              CompareRow(label: 'Tries scored a game', first: a?.triesFor, second: b?.triesFor),
              CompareRow(label: 'Tries conceded a game', first: a?.triesAgainst, second: b?.triesAgainst, lowerIsBetter: true),
            ],
            if (pts(first) != null && pts(second) != null)
              CompareRow(label: 'World Rugby ranking points', first: pts(first), second: pts(second), format: (x) => x.toStringAsFixed(1)),
            CompareRow(
                label: 'Win rate this year',
                first: a == null || a.year.every((x) => x == 0) ? null : TeamStats.winRate(a.year),
                second: b == null || b.year.every((x) => x == 0) ? null : TeamStats.winRate(b.year),
                format: (x) => '${x.round()}%'),
          ]),
        ),
        if ((a?.triesFor != null && a!.triesFrom < a.lastN) || (b?.triesFor != null && b!.triesFrom < b.lastN))
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('Tries are a game over the Tests where they’re recorded.', style: _small)),
      ]);
    }
    for (final (t, s) in [(first, a), (second, b)]) {
      if (s == null || s.recent.isEmpty) continue;
      children.addAll([
        SectionTitle('$t’s latest', note: s.streakText),
        _Tiles([
          for (final r in s.recent.take(5))
            MeetingRow(
              gender: gender,
              result: r.where == 'a'
                  ? Result(date: r.date, home: r.opponent, away: t, homeScore: r.against, awayScore: r.score, comp: r.comp)
                  : Result(date: r.date, home: t, away: r.opponent, homeScore: r.score, awayScore: r.against, comp: r.comp),
              note: r.score > r.against ? 'WON' : r.score < r.against ? 'LOST' : 'DRAW',
            ),
        ]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// A finished Test's tries, kicks and cards side by side, its try scorers, and where and who refereed.
class MatchStatsSection extends StatelessWidget {
  const MatchStatsSection({super.key, required this.result});

  final Result result;

  @override
  Widget build(BuildContext context) {
    final d = result.detail;
    if (d == null) return const SizedBox.shrink();
    double? v(int? x) => x?.toDouble();
    final facts = [
      if (d.ground.isNotEmpty) (Icons.stadium_outlined, [d.ground, if (d.city.isNotEmpty && !d.ground.contains(d.city)) d.city].join(', ')),
      if (d.crowd != null) (Icons.groups_outlined, 'Crowd ${_thousands(d.crowd!)}'),
      if (d.referee.isNotEmpty) (Icons.sports_outlined, 'Referee ${d.referee}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.hasScoring || d.hasCards) ...[
        const SectionTitle('Match stats'),
        RaCard(
          child: Column(children: [
            if (d.hasScoring) ...[
              CompareRow(label: 'Tries', first: v(d.home.tries), second: v(d.away.tries)),
              if (d.home.cons != null && d.away.cons != null) CompareRow(label: 'Conversions', first: v(d.home.cons), second: v(d.away.cons)),
              if (d.home.pens != null && d.away.pens != null) CompareRow(label: 'Penalty goals', first: v(d.home.pens), second: v(d.away.pens)),
              if ((d.home.drops ?? 0) + (d.away.drops ?? 0) > 0) CompareRow(label: 'Drop goals', first: v(d.home.drops), second: v(d.away.drops)),
            ],
            if (d.hasCards) ...[
              CompareRow(label: 'Yellow cards', first: v(d.home.yellow), second: v(d.away.yellow), lowerIsBetter: true),
              if ((d.home.red ?? 0) + (d.away.red ?? 0) > 0) CompareRow(label: 'Red cards', first: v(d.home.red), second: v(d.away.red), lowerIsBetter: true),
            ],
          ]),
        ),
      ],
      if (d.home.scorers.isNotEmpty || d.away.scorers.isNotEmpty) ...[
        const SectionTitle('Try scorers'),
        RaCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (t, s, colour) in [(result.home, d.home.scorers, RaColors.gold), (result.away, d.away.scorers, RaColors.away)])
              if (s.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: colour, fontSize: 13)),
                    Text(s.split(';').map((x) => x.trim()).join(', '), style: const TextStyle(color: RaColors.ink)),
                  ]),
                ),
          ]),
        ),
      ],
      if (facts.isNotEmpty) ...[
        const SizedBox(height: 10),
        RaCard(
          child: Column(children: [
            for (final (icon, text) in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(icon, size: 18, color: RaColors.gold),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(color: RaColors.muted))),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// A nation's record at a glance: all-time, this year, the last ten, and averages.
class TeamNumbers extends StatelessWidget {
  const TeamNumbers(this.stats, {super.key});

  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    Widget box(String big, String label, String sub) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(color: RaColors.cardHi, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(big, style: displayStyle(20, color: RaColors.gold, weight: FontWeight.w800)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: RaColors.faint)),
            ]),
          ),
        );
    String wdl(List<int> x) => x.length < 3 ? '' : '${x[0]}–${x[1]}–${x[2]}';
    final played = s.allTime.fold(0, (a, b) => a + b);
    return RaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          box(pct(TeamStats.winRate(s.allTime)), 'All-time wins', '$played Tests since ${s.since}'),
          const SizedBox(width: 8),
          box(s.year.every((x) => x == 0) ? '–' : wdl(s.year), 'This year', 'won–drawn–lost'),
          const SizedBox(width: 8),
          box(wdl(s.last), 'Last ${s.lastN}', s.streakText),
        ])),
        const SizedBox(height: 12),
        Text('Over the last ${s.lastN} Tests', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RaColors.gold)),
        const SizedBox(height: 4),
        _line('Points a game', '${_num(s.pointsFor)} scored · ${_num(s.pointsAgainst)} conceded'),
        if (s.triesFor != null) _line('Tries a game', '${_num(s.triesFor!)} scored · ${_num(s.triesAgainst!)} conceded'),
        _line('Average margin', signed((s.pointsFor - s.pointsAgainst).round())),
      ]),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: RaColors.muted))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

/// A tournament's numbers: points and tries a game, biggest win, highest score, attack and defence, top try scorers.
class TournamentStatsSection extends StatelessWidget {
  const TournamentStatsSection({super.key, required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final s = t.stats;
    if (s == null || s.games == 0) return const SizedBox.shrink();
    final feed = AppScope.of(context).matchday!;
    final teams = [for (final x in t.scoring) if (x.played > 0) x]
      ..sort((a, b) => (b.pointsFor / b.played).compareTo(a.pointsFor / a.played));
    Widget tile(String big, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(color: RaColors.cardHi, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(big, style: displayStyle(22, color: RaColors.gold, weight: FontWeight.w800)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
            ]),
          ),
        );
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RaColors.faint);
    Widget cell(String x, {bool strong = false}) =>
        SizedBox(width: 50, child: Text(x, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)));
    final bestAttack = teams.isEmpty ? null : teams.first.team;
    final bestDefence = teams.isEmpty ? null : (teams.toList()..sort((a, b) => (a.pointsAgainst / a.played).compareTo(b.pointsAgainst / b.played))).first.team;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Tournament stats', note: '${s.games} ${s.games == 1 ? 'game' : 'games'} played'),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            tile(_num(s.avgPoints), 'points a game'),
            const SizedBox(width: 8),
            tile(s.avgTries == null ? '–' : _num(s.avgTries!), 'tries a game'),
          ]),
          if (s.biggest != null) ...[const SizedBox(height: 12), const Text('Biggest win', style: _small)],
          if (s.biggest != null) _match(context, s.biggest!),
          if (s.highest != null && s.highest!.key != s.biggest?.key) ...[const SizedBox(height: 8), const Text('Most points in a game', style: _small)],
          if (s.highest != null && s.highest!.key != s.biggest?.key) _match(context, s.highest!),
        ]),
      ),
      if (teams.isNotEmpty) ...[
        const SectionTitle('Attack and defence', note: 'A game'),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(children: [
                const Expanded(child: Text('TEAM', style: head)),
                const SizedBox(width: 50, child: Text('SCORED', textAlign: TextAlign.right, style: head)),
                const SizedBox(width: 50, child: Text('LET IN', textAlign: TextAlign.right, style: head)),
                if (s.tries.isNotEmpty) const SizedBox(width: 50, child: Text('TRIES', textAlign: TextAlign.right, style: head)),
              ]),
            ),
            for (final x in teams)
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: RaColors.line))),
                child: Row(children: [
                  TeamBadge(feed.nation(x.team), size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(x.team, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  cell(_num(x.pointsFor / x.played), strong: x.team == bestAttack),
                  cell(_num(x.pointsAgainst / x.played), strong: x.team == bestDefence),
                  if (s.tries.isNotEmpty) cell(_num((s.tries[x.team] ?? 0) / x.played)),
                ]),
              ),
          ]),
        ),
        const Padding(padding: EdgeInsets.only(top: 6), child: Text('Bold: the best attack and the best defence.', style: _small)),
      ],
      if (s.scorers.isNotEmpty) ...[
        SectionTitle('Top try scorers', note: s.scorersFrom < s.games ? 'From ${s.scorersFrom} of ${s.games} games' : null),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, x) in s.scorers.indexed)
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: RaColors.line))),
                child: Row(children: [
                  TeamBadge(feed.nation(x.team), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(x.player, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(x.team, style: _small),
                    ]),
                  ),
                  Text('${x.tries}', style: displayStyle(18, color: RaColors.gold, weight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }

  Widget _match(BuildContext context, Result r) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openResult(context, tournament.gender, r),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text('${r.home} v ${r.away}', style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${r.homeScore}–${r.awayScore}', style: displayStyle(15)),
              const SizedBox(width: 8),
              Text(shortDate(r.date), style: _small),
            ]),
          ),
        ),
      );
}

/// A card holding rows with dividers between them.
class _Tiles extends StatelessWidget {
  const _Tiles(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1), children[i]],
          ]),
        ),
      );
}
