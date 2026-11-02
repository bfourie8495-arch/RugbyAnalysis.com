import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../screens/team_screen.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'common.dart';

/// A league table. [highlight] marks one team (the team page's own); teams
/// you follow are always in gold. Tapping a team opens its page.
class StandingsTable extends StatelessWidget {
  const StandingsTable({super.key, required this.gender, required this.rows, this.highlight, this.compact = false});

  final Gender gender;
  final List<StandingRow> rows;
  final String? highlight;
  final bool compact; // fewer columns, for cards

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final cols = compact ? ['P', 'W', 'L', 'PD', 'Pts'] : ['P', 'W', 'D', 'L', 'PD', 'BP', 'Pts'];
    List<String> values(StandingRow r) => compact
        ? ['${r.played}', '${r.won}', '${r.lost}', signed(r.diff), '${r.points}']
        : ['${r.played}', '${r.won}', '${r.drawn}', '${r.lost}', signed(r.diff), '${r.bonus}', '${r.points}'];
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RaColors.faint, letterSpacing: 0.5);
    Widget cell(String s, {TextStyle? style, double w = 30}) =>
        SizedBox(width: w, child: Text(s, textAlign: TextAlign.right, style: style ?? const TextStyle(fontSize: 13)));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Row(children: [const Expanded(child: Text('TEAM', style: head)), for (final h in cols) cell(h, style: head, w: h == 'PD' ? 36 : 30)]),
      ),
      for (final r in rows)
        Material(
          color: r.team == highlight ? RaColors.cardHi : Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(gender: gender, team: r.team))),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: RaColors.line))),
              child: Row(children: [
                SizedBox(width: 20, child: Text('${r.pos}', style: const TextStyle(fontWeight: FontWeight.w700, color: RaColors.muted))),
                TeamBadge(feed.nation(r.team), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.team,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: r.team == highlight || c.isFollowing(gender, r.team) ? RaColors.gold : RaColors.ink)),
                ),
                for (final (i, v) in values(r).indexed)
                  cell(v,
                      w: cols[i] == 'PD' ? 36 : 30,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: cols[i] == 'Pts' ? FontWeight.w800 : FontWeight.w400,
                          color: cols[i] == 'BP' ? RaColors.faint : RaColors.ink)),
              ]),
            ),
          ),
        ),
    ]);
  }
}
