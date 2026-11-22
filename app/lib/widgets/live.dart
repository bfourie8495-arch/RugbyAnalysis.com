import 'package:flutter/material.dart';

import '../models/live.dart';
import '../theme.dart';
import 'common.dart';

/// The gold pill by a live score: a dot and "54'", 'HT' or 'FT' (no dot once it's over).
class LivePill extends StatelessWidget {
  const LivePill(this.game, {super.key, this.large = false});

  final LiveGame game;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final on = game.state == LiveState.live || game.state == LiveState.halfTime;
    return Semantics(
      label: game.spoken,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 3 : 2),
        decoration: BoxDecoration(color: on ? RaColors.gold : RaColors.cardHi, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (on) ...[Icon(Icons.circle, size: large ? 8 : 7, color: RaColors.onGold), const SizedBox(width: 4)],
          Text(game.label,
              style: TextStyle(fontSize: large ? 13 : 11, fontWeight: FontWeight.w800, color: on ? RaColors.onGold : RaColors.ink)),
        ]),
      ),
    );
  }
}

/// The middle of the match screen while a Test is on: the score, big, and where the game is.
class LiveScore extends StatelessWidget {
  const LiveScore({super.key, required this.game, required this.home, required this.away});

  final LiveGame game;
  final String home; // as the screen names them (the feed's order)
  final String away;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$home ${game.scoreOf(home)}, $away ${game.scoreOf(away)}. ${game.spoken}',
      excludeSemantics: true,
      child: Column(children: [
        Text('${game.scoreOf(home)}–${game.scoreOf(away)}', style: displayStyle(30, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        LivePill(game, large: true),
      ]),
    );
  }
}

/// Every try, kick and card so far, the latest at the top: minute, what, who, and the score after it.
class LiveTimeline extends StatelessWidget {
  const LiveTimeline({super.key, required this.game, required this.home, required this.away});

  final LiveGame game;
  final String home;
  final String away;

  @override
  Widget build(BuildContext context) {
    // the running score after each play, in the screen's order (home on the left)
    var h = 0, a = 0;
    final rows = <(LiveEvent, int, int)>[];
    final screenHome = game.home == home;
    for (final e in game.events) {
      final forLeft = e.home == screenHome;
      if (forLeft) {
        h += e.points;
      } else {
        a += e.points;
      }
      rows.add((e, h, a));
    }
    // ESPN sometimes leaves a play out (penalty tries, or a moment behind the score): then no running scores
    final adds = h == game.scoreOf(home) && a == game.scoreOf(away);
    final note = game.state == LiveState.fullTime ? 'Full time' : 'Updates every 30 seconds';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(game.state == LiveState.fullTime ? 'How it unfolded' : 'Live', eyebrow: 'Match timeline', note: note),
      RaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: rows.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Nothing on the board yet. Tries, kicks and cards appear here as they happen.',
                    style: TextStyle(color: RaColors.muted, fontSize: 13)),
              )
            : Column(children: [
                for (final (i, (e, hs, aws)) in rows.reversed.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _EventRow(event: e, team: e.home == screenHome ? home : away, score: adds && e.points > 0 ? '$hs–$aws' : ''),
                ],
              ]),
      ),
      const SizedBox(height: 6),
      const Text('Live from ESPN. It can run a little behind the broadcast.', style: TextStyle(fontSize: 11, color: RaColors.faint)),
    ]);
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.team, required this.score});

  final LiveEvent event;
  final String team;
  final String score;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final mark = e.isCard
        ? Container(width: 12, height: 16, decoration: BoxDecoration(color: e.code == 'R' ? RaColors.redCard : RaColors.yellowCard, borderRadius: BorderRadius.circular(2)))
        : Icon(e.isTry ? Icons.sports_rugby : Icons.adjust, size: 18, color: e.isTry ? RaColors.gold : RaColors.muted);
    return Semantics(
      label: '${e.minute} minutes, ${e.what}, $team${e.player.isEmpty ? '' : ', ${e.player}'}${score.isEmpty ? '' : ', $score'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 34, child: Text("${e.minute}'", style: displayStyle(14, color: RaColors.muted))),
          SizedBox(width: 26, child: Center(child: mark)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.what, style: TextStyle(fontWeight: e.isTry ? FontWeight.w800 : FontWeight.w600)),
              Text([team, if (e.player.isNotEmpty) e.player].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
            ]),
          ),
          if (score.isNotEmpty) Text(score, style: displayStyle(15, color: e.isTry ? RaColors.ink : RaColors.muted)),
        ]),
      ),
    );
  }
}
