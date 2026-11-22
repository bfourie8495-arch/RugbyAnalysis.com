// Trends from the play-by-play (MatchTrends in feeds.dart): when tries come, who scores them, and a
// side-by-side for each fixture still to play. Shown on the tournament screen under the tournament stats.
import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../theme.dart';
import 'common.dart';

const _small = TextStyle(fontSize: 12, color: RaColors.faint);

class TrendsSection extends StatelessWidget {
  const TrendsSection({super.key, required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final t = tournament.trends;
    if (t == null || t.games == 0) return const SizedBox.shrink();
    final most = t.triesByQuarter.fold(1, (a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('What the match data says', note: '${t.games} of ${t.of} games'),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (t.insights.isNotEmpty) Text(t.insights.first, style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final line in t.insights.skip(1).take(7))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(line, style: const TextStyle(color: RaColors.muted)),
            ),
          if (t.triesByQuarter.length == t.windows.length && t.windows.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Tries by quarter', style: _small),
            const SizedBox(height: 4),
            for (var i = 0; i < t.windows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 52, child: Text('${t.windows[i]}′', style: const TextStyle(fontSize: 12, color: RaColors.muted))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: t.triesByQuarter[i] / most,
                        minHeight: 8,
                        backgroundColor: RaColors.track,
                        color: RaColors.muted,
                      ),
                    ),
                  ),
                  SizedBox(width: 36, child: Text('${t.triesByQuarter[i]}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
              ),
          ],
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _leaders('Most tries', t.tryScorers)),
            const SizedBox(width: 12),
            Expanded(child: _leaders('Most points', t.pointsScorers)),
          ]),
          const SizedBox(height: 10),
          const Text('From each game’s minute-by-minute record: tries, kicks, cards and replacements.', style: _small),
        ]),
      ),
      for (final f in tournament.fixtures)
        if (t.matchup(f.home, f.away) case final m?) ...[const SizedBox(height: 12), MatchupCard(matchup: m)],
    ]);
  }

  Widget _leaders(String title, List<({String player, String team, int n})> rows) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _small),
        const SizedBox(height: 4),
        for (final r in rows.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(
                child: Text(r.player, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
              Text('${r.n}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]);
}

/// One fixture's two teams side by side, from the play-by-play.
class MatchupCard extends StatelessWidget {
  const MatchupCard({super.key, required this.matchup});

  final TrendsMatchup matchup;

  @override
  Widget build(BuildContext context) {
    final m = matchup;
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RaColors.faint);
    return RaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${m.home} v ${m.away}', style: displayStyle(16)),
        for (final line in m.talk.take(3))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(line, style: const TextStyle(color: RaColors.muted, fontSize: 13)),
          ),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: SizedBox()),
          SizedBox(width: 76, child: Text(m.home.toUpperCase(), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: head)),
          SizedBox(width: 76, child: Text(m.away.toUpperCase(), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: head)),
        ]),
        for (final r in m.rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(r.label, style: const TextStyle(fontSize: 13, color: RaColors.muted))),
              SizedBox(width: 76, child: Text(r.home, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              SizedBox(width: 76, child: Text(r.away, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ),
      ]),
    );
  }
}
