import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'match_screen.dart';
import 'team_screen.dart';

/// Which quarter- and semi-final each round-of-16 match feeds (World Rugby's bracket).
const quarterOf = {'R16 1': 'QF 2', 'R16 2': 'QF 1', 'R16 3': 'QF 2', 'R16 4': 'QF 1', 'R16 5': 'QF 3', 'R16 6': 'QF 3', 'R16 7': 'QF 4', 'R16 8': 'QF 4'};
const semiOf = {'QF 1': 'SF 1', 'QF 2': 'SF 1', 'QF 3': 'SF 2', 'QF 4': 'SF 2'};

/// 'Winner Pool A' -> 'winner of Pool A', '3rd Pool C, E or F' -> '3rd in Pool C, E or F'.
String humanSlot(String s) => s
    .replaceFirst(RegExp(r'^Winner Pool '), 'winner of Pool ')
    .replaceFirst(RegExp(r'^2nd Pool '), 'runner-up in Pool ')
    .replaceFirst(RegExp(r'^3rd Pool '), '3rd in Pool ')
    .replaceFirst(RegExp(r'^Winner '), 'winner of ')
    .replaceFirst(RegExp(r'^Loser '), 'loser of ');

enum _Section { pools, predictions, schedule, knockouts }

/// The next World Cup: pools, the model's predictions and every team's likely
/// path, the schedule in your time, and the knockouts. A tab of its own, and
/// also opened from the World Cup strip.
class WorldCupScreen extends StatefulWidget {
  const WorldCupScreen({super.key, this.embedded = false, this.initialGender, this.team});

  final bool embedded; // true when it's the World Cup tab (no back button)
  final Gender? initialGender;
  final String? team; // open the predictions for this team

  @override
  State<WorldCupScreen> createState() => _WorldCupScreenState();
}

class _WorldCupScreenState extends State<WorldCupScreen> {
  late Gender _gender = widget.initialGender ?? Gender.men;
  late _Section _section = widget.team != null ? _Section.predictions : _Section.pools;
  String? _team; // the team whose predictions are shown
  final Map<String, String> _scenario = {}; // team -> chosen scenario key

  @override
  void initState() {
    super.initState();
    _team = widget.team;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final t = c.tournaments;
    final body = t == null
        ? const Center(child: CircularProgressIndicator(color: RaColors.gold))
        : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            if (widget.embedded) ...[Text('World Cup', style: displayStyle(22)), const SizedBox(height: 12)],
            GenderSwitch(value: _gender, onChanged: (g) => setState(() => _gender = g)),
            const SizedBox(height: 12),
            if (_gender == Gender.men) ..._men(context, c, t.worldCup) else ..._women(context, c, t.womensWorldCup),
            if (widget.embedded) const FooterLinks(),
          ]);
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('World Cup')), body: body);
  }

  // ---------------------------------------------------------------- men's 2027

  List<Widget> _men(BuildContext context, AppController c, WorldCup wc) {
    final first = wc.matches.first;
    final k = first.kickOff.toLocal();
    final days = daysUntil(wc.firstKickOff);
    final mine = c.followed(Gender.men).where((x) => wc.poolOf(x) != null).toList();
    return [
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FRI 1 OCT TO SAT 13 NOV 2027', style: TextStyle(color: RaColors.gold, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('Rugby World Cup 2027', style: displayStyle(26, weight: FontWeight.w800)),
          const Text('Australia · 8 venues from Perth to Townsville', style: TextStyle(color: RaColors.muted)),
          const SizedBox(height: 12),
          Row(children: [
            _tile(days <= 0 ? 'Live' : '$days', days <= 0 ? 'On now' : 'Days to go', lead: true),
            const SizedBox(width: 8),
            _tile('24', 'Teams'),
            const SizedBox(width: 8),
            _tile('${wc.matches.length + wc.knockouts.length}', 'Matches'),
          ]),
          const SizedBox(height: 10),
          Text('Opening match: ${first.home} v ${first.away}, ${dayLabel(k)} at ${clock(k)} your time (${first.localTime} in ${first.city}).',
              style: const TextStyle(fontSize: 12, color: RaColors.faint)),
        ]),
      ),
      if (mine.isNotEmpty) ...[
        const SectionTitle('Your teams'),
        for (final team in mine) Padding(padding: const EdgeInsets.only(bottom: 8), child: _myTeamCard(context, c, wc, team)),
      ],
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in _Section.values)
          ChoiceChip(
            label: Text(switch (s) { _Section.pools => 'Pools', _Section.predictions => 'Predictions', _Section.schedule => 'Schedule', _Section.knockouts => 'Knockouts' }),
            selected: _section == s,
            showCheckmark: false,
            labelStyle: TextStyle(color: _section == s ? RaColors.onGold : RaColors.ink, fontWeight: FontWeight.w700),
            onSelected: (_) => setState(() => _section = s),
          ),
      ]),
      const SizedBox(height: 6),
      ...switch (_section) {
        _Section.pools => _pools(context, c, wc),
        _Section.predictions => _predictions(context, c, wc, mine),
        _Section.schedule => _schedule(context, c, wc),
        _Section.knockouts => _knockouts(c, wc, mine),
      },
      const SizedBox(height: 14),
      Text(wc.format, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
    ];
  }

  Widget _tile(String big, String label, {bool lead = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDecoration(color: lead ? RaColors.gold : RaColors.page, border: lead ? RaColors.gold : RaColors.line, radius: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(big, style: displayStyle(22, weight: FontWeight.w800, color: lead ? RaColors.onGold : RaColors.ink)),
            Text(label, style: TextStyle(fontSize: 12, color: lead ? RaColors.onGold : RaColors.faint)),
          ]),
        ),
      );

  Widget _myTeamCard(BuildContext context, AppController c, WorldCup wc, String team) {
    final pool = wc.poolOf(team)!;
    final m = wc.firstMatchOf(team)!;
    final k = m.kickOff.toLocal();
    final sim = wc.teamSims[team];
    final others = [for (final r in wc.pools[pool]!) if (r.team != team) r.team];
    return RaCard(
      onTap: () => setState(() {
        _team = team;
        _section = _Section.predictions;
      }),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TeamBadge(c.matchday!.nation(team)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(team, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Pool $pool with ${others.join(', ')}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Opens v ${m.home == team ? m.away : m.home}, ${dayLabel(k)} at ${clock(k)} · ${m.city}', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (sim != null) ...[
          const SizedBox(height: 6),
          Text('Title chance ${pct(sim.win)} · semi-final ${pct(sim.reach['SF'] ?? 0)} · tap for their likely paths',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RaColors.goldSoft)),
        ],
      ]),
    );
  }

  List<Widget> _pools(BuildContext context, AppController c, WorldCup wc) {
    final side = c.matchday!.men;
    final started = wc.pools.values.any((rows) => rows.any((r) => r.played > 0));
    return [
      const SizedBox(height: 8),
      for (final e in wc.pools.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RaCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('POOL ${e.key}', style: const TextStyle(fontFamily: display, fontWeight: FontWeight.w800, color: RaColors.gold, letterSpacing: 1)),
              for (final r in e.value)
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(gender: Gender.men, team: r.team))),
                  child: SizedBox(
                    height: 40,
                    child: Row(children: [
                      TeamBadge(c.matchday!.nation(r.team), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.team,
                            style: TextStyle(fontWeight: FontWeight.w600, color: c.isFollowing(Gender.men, r.team) ? RaColors.gold : RaColors.ink)),
                      ),
                      Text(started ? '${r.points} pts' : (side.rankOf(r.team) == null ? '' : 'No. ${side.rankOf(r.team)}'),
                          style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      Text(
        started
            ? 'Points: 4 for a win, 2 for a draw, plus bonus points. The top two in each pool and the four best third-placed teams go through.'
            : 'Until the first match, each pool is listed in world ranking order (No. is the World Rugby ranking today).',
        style: const TextStyle(fontSize: 12, color: RaColors.faint),
      ),
    ];
  }

  List<Widget> _predictions(BuildContext context, AppController c, WorldCup wc, List<String> mine) {
    if (wc.titleChances.isEmpty) return const [EmptyNote('No predictions yet', 'They appear once the simulation has run.')];
    final feed = c.matchday!;
    final top = wc.titleChances.first.pct;
    final team = _team != null && wc.teamSims.containsKey(_team) ? _team! : (mine.isNotEmpty ? mine.first : wc.titleChances.first.team);
    final sim = wc.teamSims[team]!;
    final order = [...mine, for (final x in wc.titleChances) if (!mine.contains(x.team)) x.team];
    final best = sim.scenarios.reduce((a, b) => b.chance > a.chance ? b : a);
    final chosen = sim.scenarios.where((s) => s.key == _scenario[team]).firstOrNull ?? best;
    final short = {'1': 'Top Pool ${sim.pool}', '2': '2nd in Pool ${sim.pool}', '3': '3rd in Pool ${sim.pool}', 'out': 'Out in the pool'};
    return [
      const SectionTitle('Who wins it?', note: 'Title chance'),
      RaCard(
        child: Column(children: [
          for (final x in wc.titleChances.take(10))
            InkWell(
              onTap: () => setState(() => _team = x.team),
              child: ChanceBar(label: x.team, value: x.pct, scale: top, leading: TeamBadge(feed.nation(x.team), size: 22)),
            ),
        ]),
      ),
      const SectionTitle('Where could they end up?'),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final t in order)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t),
                selected: t == team,
                showCheckmark: false,
                labelStyle: TextStyle(color: t == team ? RaColors.onGold : RaColors.ink, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _team = t),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            TeamBadge(feed.nation(team)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(team, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Pool ${sim.pool} · chance of winning the World Cup', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
              ]),
            ),
            Text(pct(sim.win), style: displayStyle(26, color: RaColors.gold, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          for (final (label, key) in [('Round of 16', 'R16'), ('Quarter-final', 'QF'), ('Semi-final', 'SF'), ('Final', 'Final')])
            ChanceBar(label: label, value: sim.reach[key] ?? 0),
          ChanceBar(label: 'Champions', value: sim.win),
        ]),
      ),
      const SizedBox(height: 14),
      const Text('SCENARIOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RaColors.muted, letterSpacing: 1)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in sim.scenarios)
          ChoiceChip(
            label: Text('${short[s.key] ?? s.label} · ${pct(s.chance)}'),
            selected: s == chosen,
            showCheckmark: false,
            labelStyle: TextStyle(color: s == chosen ? RaColors.onGold : RaColors.ink, fontWeight: FontWeight.w700, fontSize: 12),
            onSelected: (_) => setState(() => _scenario[team] = s.key),
          ),
      ]),
      const SizedBox(height: 10),
      _scenarioCard(wc, chosen),
      const SizedBox(height: 8),
      const Text('“Wins” is their chance of winning that match if they get there. The opponents are who they meet most often in that round.',
          style: TextStyle(fontSize: 12, color: RaColors.faint)),
      const SizedBox(height: 6),
      Text(wc.simAbout, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
    ];
  }

  Widget _scenarioCard(WorldCup wc, WorldCupScenario s) {
    final runs = s.chance / 100 * 20000;
    final usual = s.slot.isNotEmpty && s.slotShare < 95;
    WorldCupMatch? matchFor(String stage) => switch (stage) {
          'R16' => wc.knockout(s.slot),
          'QF' => wc.knockout(quarterOf[s.slot] ?? ''),
          'SF' => wc.knockout(semiOf[quarterOf[s.slot]] ?? ''),
          _ => wc.knockout('Final'),
        };
    final stages = [for (final st in s.stages) if (st.reach * runs / 100 >= 50) st];
    return RaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('${pct(s.chance)} likely · if so, title chance ${pct(s.title)}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
        if (s.key == 'out')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Their World Cup ends after the three pool games.', style: TextStyle(color: RaColors.muted)),
          ),
        for (final st in stages) ...[
          const Divider(height: 20),
          Row(children: [
            Expanded(child: Text(st.label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('Wins ${pct(st.win)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RaColors.gold)),
          ]),
          const SizedBox(height: 3),
          Text(
            st.opponents.length == 1
                ? 'v ${st.opponents.first.team} (${pct(st.opponents.first.pct)})'
                : 'Most likely v ${[for (final o in st.opponents.take(st.opponents.length - 1)) '${o.team} (${pct(o.pct)})'].join(', ')} '
                    'or ${st.opponents.last.team} (${pct(st.opponents.last.pct)})',
            style: const TextStyle(fontSize: 13),
          ),
          if (matchFor(st.stage) case final m?)
            Text(
              '${usual ? 'Usually ' : ''}${dayLabel(m.kickOff.toLocal())}, ${clock(m.kickOff.toLocal())} · ${m.city}'
              '${st.stage == 'R16' ? '' : ' · ${pct(st.reach)} get this far'}',
              style: const TextStyle(fontSize: 12, color: RaColors.faint),
            ),
        ],
      ]),
    );
  }

  List<Widget> _schedule(BuildContext context, AppController c, WorldCup wc) {
    final byDay = <String, List<WorldCupMatch>>{};
    for (final m in wc.matches) {
      (byDay[dayLabel(m.kickOff.toLocal())] ??= []).add(m);
    }
    return [
      for (final e in byDay.entries) ...[
        Padding(padding: const EdgeInsets.fromLTRB(2, 14, 0, 8), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: RaColors.muted))),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              for (final m in e.value)
                ListTile(
                  leading: TeamBadge(c.matchday!.nation(m.home), size: 26),
                  title: Text('${m.home} v ${m.away}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c.isFollowing(Gender.men, m.home) || c.isFollowing(Gender.men, m.away) ? RaColors.gold : RaColors.ink)),
                  subtitle: Text('Pool ${m.pool} · ${m.venue}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(clock(m.kickOff.toLocal()), style: displayStyle(15)),
                    Text('${m.localTime} in ${m.city}', style: const TextStyle(fontSize: 11, color: RaColors.faint)),
                  ]),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MatchScreen(
                            gender: Gender.men,
                            fixture: Fixture(
                                date: m.date,
                                kickOff: m.kickOff,
                                home: m.home,
                                away: m.away,
                                comp: 'Rugby World Cup 2027 · Pool ${m.pool}',
                                venue: '${m.venue}, ${m.city}'),
                          ))),
                ),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 10),
      const Text('Times are in your time zone, with the local time at the ground underneath.', style: TextStyle(fontSize: 12, color: RaColors.faint)),
    ];
  }

  List<Widget> _knockouts(AppController c, WorldCup wc, List<String> mine) {
    final pools = {for (final t in mine) wc.poolOf(t)};
    bool isMine(String label) {
      final m = RegExp(r'Pool ([A-F ,or]+)$').firstMatch(label);
      if (m == null) return false;
      return RegExp('[A-F]').allMatches(m.group(1)!).any((x) => pools.contains(x.group(0)));
    }

    final rounds = <String, List<WorldCupMatch>>{};
    for (final k in wc.knockouts) {
      (rounds[k.round] ??= []).add(k);
    }
    const names = {'Quarter-final': 'Quarter-finals', 'Semi-final': 'Semi-finals'};
    return [
      for (final e in rounds.entries) ...[
        SectionTitle(names[e.key] ?? e.key),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
            for (final k in e.value)
              ListTile(
                  tileColor: isMine(k.home) || isMine(k.away) ? RaColors.cardHi : null,
                  leading: SizedBox(
                    width: 54,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dayLabel(k.kickOff.toLocal()).substring(0, 6), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(clock(k.kickOff.toLocal()), style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                    ]),
                  ),
                  title: Text('${k.id == 'Final' || k.id == 'Bronze' ? '' : '${k.id}: '}${humanSlot(k.home)} v ${humanSlot(k.away)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${k.venue}, ${k.city} · ${k.localTime} local', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                ),
          ]),
          ),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- women's 2029

  List<Widget> _women(BuildContext context, AppController c, WomensWorldCup w) {
    final side = c.matchday!.women;
    return [
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DATES TO BE ANNOUNCED', style: TextStyle(color: RaColors.gold, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(w.name, style: displayStyle(24, weight: FontWeight.w800)),
          Text('${w.host} · ${w.teams} teams', style: const TextStyle(color: RaColors.muted)),
          const Divider(height: 20),
          Text(w.note, style: const TextStyle(fontSize: 13, color: RaColors.muted)),
        ]),
      ),
      SectionTitle('Already qualified', note: '${w.qualified.length} of ${w.teams}'),
      Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(children: [
            for (final q in w.qualified)
              ListTile(
                leading: TeamBadge(c.matchday!.nation(q.team)),
                title: Text(q.team, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(q.how, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                trailing: Text(side.rankOf(q.team) == null ? '' : 'World No. ${side.rankOf(q.team)}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(gender: Gender.women, team: q.team))),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      const Text('The rest of the field qualifies through the WXV Global Series cycle and regional tournaments up to 2028.',
          style: TextStyle(fontSize: 12, color: RaColors.faint)),
    ];
  }
}
