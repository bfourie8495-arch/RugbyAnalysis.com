import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/match_tiles.dart';
import '../widgets/standings.dart';
import '../widgets/insights.dart';
import '../widgets/stats.dart';
import 'tournament_screen.dart';
import 'tournaments_screen.dart';
import 'world_cup_screen.dart';

/// A nation: follow it, its form and next games, the World Cup, every
/// tournament it's in with its table, and recent results.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key, required this.gender, required this.team});

  final Gender gender;
  final String team;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final side = feed.side(gender);
    final n = feed.nation(team);
    final following = c.isFollowing(gender, team);
    final rank = side.rankOf(team);
    final next = side.fixtures.where((f) => f.involves(team)).take(3).toList();
    final results = side.results.where((r) => r.involves(team)).take(6).toList();
    final entries = c.tournaments?.entriesFor(gender, team) ?? const <TeamEntry>[];
    return Scaffold(
      appBar: AppBar(title: Text(gender == Gender.men ? 'Men’s Tests' : 'Women’s Tests')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: n.primary, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              TeamBadge(n, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (n.nick.isNotEmpty && gender == Gender.men)
                    Text(n.nick.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: n.onPrimary)),
                  Text(team, style: displayStyle(26, color: n.onPrimary, weight: FontWeight.w800)),
                  Text(rank == null ? 'Unranked' : 'World No. $rank', style: TextStyle(color: n.onPrimary)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: n.onPrimary, foregroundColor: n.primary, minimumSize: const Size.fromHeight(44)),
                onPressed: () => c.toggleFollow(gender, team),
                icon: Icon(following ? Icons.star : Icons.star_border),
                label: Text(following ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            if (following)
              Center(
                child: c.isMyTeam(gender, team)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text('Your team', style: TextStyle(color: n.onPrimary, fontWeight: FontWeight.w700)),
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: n.onPrimary, minimumSize: const Size(0, 44)),
                        onPressed: () => c.makeMyTeam(gender, team),
                        icon: const Icon(Icons.favorite_border, size: 18),
                        label: Text('Make $team your team', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
              ),
          ]),
        ),
        if ((side.form[team] ?? '').isNotEmpty) ...[
          const SectionTitle('Form', note: 'Most recent on the right'),
          RaCard(child: Align(alignment: Alignment.centerLeft, child: FormDots(side.form[team]!))),
        ],
        if (side.stats[team] case final s?) ...[
          const SectionTitle('By the numbers'),
          TeamNumbers(s),
          SeasonSection(gender: gender, team: team, stats: s),
          TrendSection(stats: s),
        ],
        if (next.isNotEmpty) ...[
          const SectionTitle('Next up'),
          TileList(children: [for (final f in next) FixtureTile(gender: gender, fixture: f)]),
        ],
        if (c.tournaments != null) ...[
          const SectionTitle('Tournaments'),
          _worldCupCard(context, c),
          for (final e in entries)
            if (c.tournaments!.byId(e.id) case final t?) Padding(padding: const EdgeInsets.only(top: 8), child: _tournamentCard(context, t, e)),
        ],
        if (results.isNotEmpty) ...[
          const SectionTitle('Recent results'),
          TileList(children: [for (final r in results) ResultTile(gender: gender, result: r)]),
        ] else if (side.stats[team]?.recent case final recent? when recent.isNotEmpty) ...[
          const SectionTitle('Recent results'),
          TileList(children: [
            for (final r in recent.take(6))
              MeetingRow(
                gender: gender,
                result: r.where == 'a'
                    ? Result(date: r.date, home: r.opponent, away: team, homeScore: r.against, awayScore: r.score, comp: r.comp)
                    : Result(date: r.date, home: team, away: r.opponent, homeScore: r.score, awayScore: r.against, comp: r.comp),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _worldCupCard(BuildContext context, AppController c) {
    final t = c.tournaments!;
    if (gender == Gender.women) {
      final q = t.womensWorldCup.qualified.where((x) => x.team == team).firstOrNull;
      return RaCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorldCupScreen(initialGender: Gender.women))),
        child: _wcRow('Women’s Rugby World Cup 2029', 'Australia · dates to be announced', q != null ? 'Qualified' : 'Not yet',
            q != null ? 'In, as ${q.how.toLowerCase()}.' : 'Not qualified yet: the rest of the 16 teams come through the WXV cycle and regional tournaments.'),
      );
    }
    final wc = t.worldCup;
    final pool = wc.poolOf(team);
    if (pool == null) {
      return RaCard(child: _wcRow('Rugby World Cup 2027', 'Australia, 1 Oct to 13 Nov 2027', 'Not in', '$team aren’t among the 24 teams going to Australia.'));
    }
    final m = wc.firstMatchOf(team)!;
    final k = m.kickOff.toLocal();
    final sim = wc.teamSims[team];
    return RaCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorldCupScreen(initialGender: Gender.men, team: team))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _wcRow('Rugby World Cup 2027 · Pool $pool', 'Australia, 1 Oct to 13 Nov 2027', '${daysUntil(wc.firstKickOff)} days',
            'Opens v ${m.home == team ? m.away : m.home}, ${dayLabel(k)} at ${clock(k)} · ${m.city}'),
        if (sim != null) ...[
          const SizedBox(height: 6),
          Text('Title chance ${pct(sim.win)} · semi-final ${pct(sim.reach['SF'] ?? 0)} · tap for their likely paths',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RaColors.goldSoft)),
        ],
      ]),
    );
  }

  Widget _wcRow(String title, String sub, String tag, String line) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events_outlined, color: RaColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            ]),
          ),
          Tag(tag),
        ]),
        const SizedBox(height: 8),
        Text(line, style: const TextStyle(fontSize: 13, color: RaColors.muted)),
      ]);

  Widget _tournamentCard(BuildContext context, Tournament t, TeamEntry e) {
    final done = t.status == TournamentStatus.done;
    final simTeam = t.sim?.teams[team];
    return RaCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentScreen(id: t.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700))),
          Tag(TournamentsScreen.statusLabel(t.status), strong: t.status == TournamentStatus.live),
        ]),
        const SizedBox(height: 6),
        if (t.isSeries)
          Text('${e.record.join('–')}  won–drawn–lost', style: displayStyle(20, color: RaColors.gold))
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(done && e.pos == 1 ? 'Champions' : ordinal(e.pos), style: displayStyle(28, color: RaColors.gold, weight: FontWeight.w800)),
            const SizedBox(width: 10),
            Text('${done && e.pos == 1 ? '' : 'of ${e.of} · '}${e.points} pts', style: const TextStyle(color: RaColors.muted)),
          ]),
          const SizedBox(height: 4),
          StandingsTable(gender: gender, rows: t.groups[e.group].rows, highlight: team, compact: true),
        ],
        if (simTeam != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Model: most likely to finish ${ordinal(simTeam.likeliestPlace)} (${pct(simTeam.place[simTeam.likeliestPlace - 1])})'
              '${simTeam.opponents.isEmpty ? '' : ' · most often meets ${simTeam.opponents.first.team} at Twickenham (${pct(simTeam.opponents.first.pct)})'}'
              ' · wins there ${pct(simTeam.finalWin)} · title ${pct(simTeam.title)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RaColors.goldSoft),
            ),
          ),
      ]),
    );
  }
}
