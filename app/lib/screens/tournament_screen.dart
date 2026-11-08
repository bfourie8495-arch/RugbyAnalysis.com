import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../models/stage.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/standings.dart';
import '../widgets/insights.dart';
import '../widgets/stats.dart';
import 'match_screen.dart';
import 'team_screen.dart';
import 'tournaments_screen.dart';

/// One tournament: its tables (or each team's record, for a series), the
/// model's predictions where there's a simulation, what's still to play and
/// the latest results.
class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final t = c.tournaments?.byId(id);
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: t == null
          ? const Center(child: Text('This tournament is no longer in the feed.'))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              RaCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(t.season, style: const TextStyle(color: RaColors.gold, fontWeight: FontWeight.w700))),
                    Tag(TournamentsScreen.statusLabel(t.status), strong: t.status == TournamentStatus.live),
                  ]),
                  const SizedBox(height: 6),
                  Text(t.name, style: displayStyle(26, weight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const _Label('Where it’s at'),
                  Text(whereItsAt(t), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const _Label('How it works'),
                  Text(t.about, style: const TextStyle(color: RaColors.muted)),
                  if (t.finals.isNotEmpty && t.status != TournamentStatus.done) ...[
                    const SizedBox(height: 6),
                    Text(t.finals, style: const TextStyle(color: RaColors.muted)),
                  ],
                ]),
              ),
              if (t.isSeries) ..._series(context, t) else ..._tables(t),
              TitleMovesSection(tournament: t),
              if (t.sim != null) ..._predictions(context, c, t),
              TournamentStatsSection(tournament: t),
              if (t.fixtures.isNotEmpty) ...[
                SectionTitle('Still to play', note: '${t.fixtures.length} matches'),
                _list([
                  for (final f in t.fixtures)
                    _fixtureRow(context, t.gender, f),
                ]),
              ],
              if (t.results.isNotEmpty) ...[
                const SectionTitle('Latest results'),
                _list([
                  for (final r in t.results.reversed.take(12))
                    ListTile(
                      title: Text('${r.home} v ${r.away}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(shortDate(r.date), style: const TextStyle(color: RaColors.faint, fontSize: 12)),
                      trailing: Text('${r.homeScore}–${r.awayScore}', style: displayStyle(16)),
                      onTap: () => openResult(context, t.gender, r),
                    ),
                ]),
              ],
            ]),
    );
  }

  Widget _list(List<Widget> children) => Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(color: Colors.transparent, child: Column(children: children)),
      );

  List<Widget> _tables(Tournament t) => [
        for (final g in t.groups) ...[
          SectionTitle(g.name.isEmpty ? 'Table' : g.name,
              note: t.status == TournamentStatus.done ? 'Final' : 'After ${g.rows.map((r) => r.played).fold(0, (a, b) => a > b ? a : b)} rounds'),
          _list([StandingsTable(gender: t.gender, rows: g.rows)]),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'BP: bonus points, one for scoring four or more tries and one for losing by seven or fewer. '
            '${t.checked ? 'Worked out from the results.' : 'Worked out from results with the usual points: there’s no published table to check it against yet.'}',
            style: const TextStyle(fontSize: 12, color: RaColors.faint),
          ),
        ),
      ];

  List<Widget> _series(BuildContext context, Tournament t) {
    final feed = AppScope.of(context).matchday!;
    return [
      const SectionTitle('Records in the series', note: 'No league table'),
      _list([
        for (final r in t.records)
          ListTile(
            leading: TeamBadge(feed.nation(r.team), size: 26),
            title: Text(r.team, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Played ${r.played} · points difference ${signed(r.diff)}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            trailing: Text('${r.won}–${r.drawn}–${r.lost}', style: displayStyle(16)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(gender: t.gender, team: r.team))),
          ),
      ]),
    ];
  }

  List<Widget> _predictions(BuildContext context, AppController c, Tournament t) {
    final sim = t.sim!;
    final feed = c.matchday!;
    final top = sim.title.isEmpty ? 1.0 : sim.title.first.pct;
    const names = ['1st v 1st', '2nd v 2nd', '3rd v 3rd', '4th v 4th', '5th v 5th', '6th v 6th'];
    return [
      const SectionTitle('Who wins it?', eyebrow: 'Model predictions', note: 'Title chance'),
      RaCard(
        child: Column(children: [
          for (final x in sim.title.where((x) => x.pct >= 0.5).take(8))
            ChanceBar(label: x.team, value: x.pct, scale: top, leading: TeamBadge(feed.nation(x.team), size: 22)),
        ]),
      ),
      const SectionTitle('Likely finals weekend', note: 'Twickenham'),
      _list([
        for (final f in sim.finals)
          ListTile(
            leading: SizedBox(
              width: 54,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.kickOff == null ? '' : dayLabel(f.kickOff!.toLocal()).substring(0, 6), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(f.kickOff == null ? '' : clock(f.kickOff!.toLocal()), style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                ]),
              ),
            ),
            title: Text(names[(f.place - 1).clamp(0, 5)] + (f.place == 1 ? ': the title decider' : ''), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              f.pairs.isEmpty
                  ? ''
                  : 'Most likely ${f.pairs.first.a} v ${f.pairs.first.b} (${pct(f.pairs.first.pct)})'
                      '${f.pairs.length > 1 ? '\nOr ${[for (final p in f.pairs.skip(1)) '${p.a} v ${p.b} (${pct(p.pct)})'].join(', ')}' : ''}',
              style: const TextStyle(fontSize: 12, color: RaColors.muted),
            ),
          ),
      ]),
      for (final g in t.groups) ...[
        SectionTitle(g.name, note: 'Chance of each final place'),
        _list([_placeTable(context, t.gender, g, sim)]),
      ],
      Padding(padding: const EdgeInsets.only(top: 10), child: Text('${sim.about} Chances are rounded.', style: const TextStyle(fontSize: 12, color: RaColors.faint))),
    ];
  }

  Widget _placeTable(BuildContext context, Gender gender, TableGroup g, GroupSim sim) {
    final c = AppScope.of(context);
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RaColors.faint);
    Widget cell(String s, {bool hot = false}) => SizedBox(
          width: 38,
          child: Text(s, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: hot ? FontWeight.w800 : FontWeight.w400, color: hot ? RaColors.gold : RaColors.ink)),
        );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(children: [const Expanded(child: Text('TEAM', style: head)), for (var i = 1; i <= 6; i++) SizedBox(width: 38, child: Text(ordinal(i), textAlign: TextAlign.right, style: head))]),
      ),
      for (final r in g.rows)
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.isFollowing(gender, r.team) ? RaColors.cardHi : null,
            border: const Border(top: BorderSide(color: RaColors.line)),
          ),
          child: Row(children: [
            TeamBadge(c.matchday!.nation(r.team), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(c.matchday!.nation(r.team).code, style: const TextStyle(fontWeight: FontWeight.w600))),
            for (final (i, x) in (sim.teams[r.team]?.place ?? const <double>[]).indexed)
              cell(x <= 0 ? '–' : pct(x), hot: i + 1 == sim.teams[r.team]!.likeliestPlace),
          ]),
        ),
    ]);
  }

  Widget _fixtureRow(BuildContext context, Gender g, Fixture f) {
    final k = f.kickOff?.toLocal();
    final p = pickOf(f.home, f.away, f.pick);
    return ListTile(
      title: Text('${f.home} v ${f.away}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([f.venue, if (p != null) 'Pick: ${p.team} ${p.pct}%'].where((x) => x.isNotEmpty).join(' · '),
          style: const TextStyle(fontSize: 12, color: RaColors.faint)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(k == null ? dateLabel(f.date) : dayLabel(k), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        Text(k == null ? 'TBC' : clock(k), style: const TextStyle(fontSize: 12, color: RaColors.faint)),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(gender: g, fixture: f))),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: RaColors.gold)),
      );
}
