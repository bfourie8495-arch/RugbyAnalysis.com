import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../screens/match_screen.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'stats.dart';

/// An upcoming Test: both teams with their form, kick-off in your time, and the model's pick.
class FixtureTile extends StatelessWidget {
  const FixtureTile({super.key, required this.gender, required this.fixture, this.tag});

  final Gender gender;
  final Fixture fixture;
  final Widget? tag; // e.g. 'Your team' on the weekend list

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final side = feed.side(gender);
    final k = fixture.kickOff?.toLocal();
    Widget team(String t) => Row(children: [
          TeamBadge(feed.nation(t), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: c.isFollowing(gender, t) ? RaColors.gold : RaColors.ink)),
          ),
          if ((side.form[t] ?? '').isNotEmpty) FormDots(side.form[t]!),
        ]);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(gender: gender, fixture: fixture))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [team(fixture.home), const SizedBox(height: 8), team(fixture.away)])),
            const SizedBox(width: 12),
            KickOffBlock(fixture: fixture),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(fixture.comp, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
            ),
            if (tag != null) ...[const SizedBox(width: 8), tag!],
          ]),
          if (fixture.pick != null) ...[
            const SizedBox(height: 8),
            PickBar(home: fixture.home, away: fixture.away, homeChance: fixture.pick!),
          ],
        ]),
      ),
    );
  }
}

/// When a Test kicks off, easy to read at a glance: the day ('Today', 'Tomorrow', 'Sat 7 Nov'), the time in
/// your time zone, and how long to go (or 'Live', or 'Result soon' once it's over).
class KickOffBlock extends StatelessWidget {
  const KickOffBlock({super.key, required this.fixture, this.large = false});

  final Fixture fixture;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final k = fixture.kickOff?.toLocal();
    final day = k == null ? dateLabel(fixture.date) : kickOffDay(k);
    final note = k == null ? null : kickOffNote(k, live: fixture.live);
    final today = day == 'Today' || note == 'Live';
    final live = note == 'Live';
    return Semantics(
      label: 'Kick-off ${k == null ? '$day, time to be confirmed' : '$day at ${clock(k)}'}${note == null ? '' : ', $note'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: large ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day.toUpperCase(),
              style: TextStyle(fontSize: large ? 12 : 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: today ? RaColors.gold : RaColors.muted)),
          Text(k == null ? 'TBC' : clock(k), style: displayStyle(large ? 26 : 21, weight: FontWeight.w800)),
          if (note != null)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: live ? RaColors.gold : RaColors.cardHi,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (live) ...[const Icon(Icons.circle, size: 7, color: RaColors.onGold), const SizedBox(width: 4)],
                Text(note, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: live ? RaColors.onGold : RaColors.ink)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// A finished Test: the winner in bold, the loser's score dimmed.
class ResultTile extends StatelessWidget {
  const ResultTile({super.key, required this.gender, required this.result});

  final Gender gender;
  final Result result;

  @override
  Widget build(BuildContext context) {
    final feed = AppScope.of(context).matchday!;
    final r = result;
    Widget row(String t, int score, int other) {
      final won = score > other, lost = score < other;
      return Row(children: [
        TeamBadge(feed.nation(t), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(t,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: won ? FontWeight.w800 : FontWeight.w500, color: lost ? RaColors.muted : RaColors.ink)),
        ),
        Text('$score', style: displayStyle(17, color: lost ? RaColors.faint : RaColors.ink)),
      ]);
    }

    return InkWell(
      onTap: () => openResult(context, gender, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(child: Column(children: [row(r.home, r.homeScore, r.awayScore), const SizedBox(height: 6), row(r.away, r.awayScore, r.homeScore)])),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(shortDate(r.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: RaColors.faint)),
              Text(r.comp, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: RaColors.faint, height: 1.25)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A card holding a list of tiles with dividers between them.
class TileList extends StatelessWidget {
  const TileList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ]),
      ),
    );
  }
}
