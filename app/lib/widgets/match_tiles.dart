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
          Row(children: [
            Expanded(child: Column(children: [team(fixture.home), const SizedBox(height: 8), team(fixture.away)])),
            const SizedBox(width: 12),
            SizedBox(
              width: 86,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(k == null ? 'TBC' : clock(k), style: displayStyle(16)),
                const SizedBox(height: 2),
                Text(fixture.comp, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: RaColors.faint, height: 1.25)),
                if (tag != null) ...[const SizedBox(height: 4), tag!],
              ]),
            ),
          ]),
          if (fixture.pick != null) ...[
            const SizedBox(height: 10),
            PickBar(home: fixture.home, away: fixture.away, homeChance: fixture.pick!),
          ],
        ]),
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
