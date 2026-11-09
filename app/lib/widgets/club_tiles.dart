import 'package:flutter/material.dart';

import '../models/clubs.dart';
import '../models/feeds.dart' show Fixture;
import '../models/format.dart';
import '../screens/club_screen.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'match_tiles.dart' show KickOffBlock;

/// A club's mark: its short code in a circle of its colours (clubs have no flag).
class ClubBadge extends StatelessWidget {
  const ClubBadge(this.club, {super.key, this.size = 30});

  final Club club;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: club.name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: club.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
        child: Text(club.code,
            style: TextStyle(fontSize: size * (club.code.length > 3 ? 0.24 : 0.3), fontWeight: FontWeight.w800, color: club.onPrimary, height: 1)),
      ),
    );
  }
}

void openClub(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubScreen(id: id)));

/// What a club game was in: 'URC · Round 6 · St Helen's, Swansea'. [showComp] is off inside a competition's own page.
String clubGameNote(ClubsFeed feed, ClubGame g, {bool showComp = true}) => [
      if (showComp && g.comp.isNotEmpty) feed.league(g.comp)?.short ?? g.comp,
      if (g.round != null) 'Round ${g.round}',
      if (g.venue.isNotEmpty) g.venue,
    ].join(' · ');

/// One club game: both clubs, then the score (played) or the kick-off in your time (to come).
/// [focus] is the club whose page this is: its result shows as a W, D or L.
class ClubGameTile extends StatelessWidget {
  const ClubGameTile({super.key, required this.game, this.focus, this.showComp = true});

  final ClubGame game;
  final String? focus;
  final bool showComp;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.clubs!;
    final g = game;
    Widget row(String id, int? score, int? other) {
      final club = feed.club(id);
      final won = score != null && other != null && score > other, lost = score != null && other != null && score < other;
      final mine = c.isFollowingClub(id) || id == focus;
      return InkWell(
        onTap: id == focus ? null : () => openClub(context, id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 30),
          child: Row(children: [
            ClubBadge(club, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(club.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: won ? FontWeight.w800 : FontWeight.w600,
                      color: mine ? RaColors.gold : lost ? RaColors.muted : RaColors.ink)),
            ),
            if (score != null) Text('$score', style: displayStyle(17, color: lost ? RaColors.faint : RaColors.ink)),
          ]),
        ),
      );
    }

    final note = clubGameNote(feed, g, showComp: showComp);
    final res = focus == null ? '' : g.resultFor(focus!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [row(g.home, g.homeScore, g.awayScore), const SizedBox(height: 4), row(g.away, g.awayScore, g.homeScore)])),
          const SizedBox(width: 12),
          if (g.played)
            SizedBox(
              width: 64,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(shortDate(g.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: RaColors.faint)),
                if (res.isNotEmpty) ...[const SizedBox(height: 4), _ResultMark(res)],
              ]),
            )
          else
            KickOffBlock(fixture: Fixture(date: g.date, home: g.home, away: g.away, kickOff: g.kickOff)),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
        ],
      ]),
    );
  }
}

class _ResultMark extends StatelessWidget {
  const _ResultMark(this.r);

  final String r;

  @override
  Widget build(BuildContext context) {
    final label = switch (r) { 'W' => 'Won', 'L' => 'Lost', _ => 'Drew' };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: r == 'W' ? RaColors.gold : RaColors.track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: r == 'W' ? RaColors.onGold : RaColors.ink)),
    );
  }
}

/// A competition's table. The play-off places sit above a gold line; [highlight] marks one club;
/// clubs you follow are in gold. Tapping a club opens its page.
class ClubTable extends StatelessWidget {
  const ClubTable({super.key, required this.league, this.highlight, this.compact = false});

  final ClubLeague league;
  final String? highlight;
  final bool compact; // fewer columns, for the club page

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.clubs!;
    final cols = compact ? ['P', 'W', 'PD', 'Pts'] : ['P', 'W', 'D', 'L', 'PD', 'BP', 'Pts'];
    List<String> values(ClubRow r) => compact
        ? ['${r.played}', '${r.won}', signed(r.diff), '${r.points}']
        : ['${r.played}', '${r.won}', '${r.drawn}', '${r.lost}', signed(r.diff), '${r.bonus}', '${r.points}'];
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RaColors.faint, letterSpacing: 0.5);
    Widget cell(String s, {TextStyle? style, double w = 28}) =>
        SizedBox(width: w, child: Text(s, textAlign: TextAlign.right, style: style ?? const TextStyle(fontSize: 13)));
    double width(String h) => h == 'PD' ? 38 : h == 'Pts' ? 32 : 26;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Row(children: [const Expanded(child: Text('CLUB', style: head)), for (final h in cols) cell(h, style: head, w: width(h))]),
      ),
      for (final (i, r) in league.table.indexed)
        Material(
          color: r.club == highlight ? RaColors.cardHi : Colors.transparent,
          child: InkWell(
            onTap: r.club == highlight ? null : () => openClub(context, r.club),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: league.playoff > 0 && i == league.playoff
                      ? const BorderSide(color: RaColors.gold, width: 1.5)
                      : const BorderSide(color: RaColors.line),
                ),
              ),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: RaColors.muted))),
                ClubBadge(feed.club(r.club), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(feed.club(r.club).name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: r.club == highlight || c.isFollowingClub(r.club) ? RaColors.gold : RaColors.ink)),
                ),
                for (final (j, v) in values(r).indexed)
                  cell(v,
                      w: width(cols[j]),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: cols[j] == 'Pts' ? FontWeight.w800 : FontWeight.w400,
                          color: cols[j] == 'BP' ? RaColors.faint : RaColors.ink)),
              ]),
            ),
          ),
        ),
      if (league.playoff > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Row(children: [
            Container(width: 16, height: 1.5, color: RaColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Top ${league.playoff} reach the play-offs', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            ),
          ]),
        ),
    ]);
  }
}
