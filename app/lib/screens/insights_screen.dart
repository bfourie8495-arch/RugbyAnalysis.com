import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/insights.dart';

/// Talking points: what the latest results did to the title races, the year's biggest upsets and who's
/// scoring the tries.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.gender});

  final Gender gender;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final live = [for (final t in c.tournaments?.tournaments ?? <Tournament>[]) if (t.gender == gender && t.moves != null) t];
    return Scaffold(
      appBar: AppBar(title: const Text('Talking points')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        for (final t in live) TitleMovesSection(tournament: t, title: t.title),
        UpsetsSection(gender: gender),
        HotScorersSection(gender: gender),
        const SizedBox(height: 12),
        const Text(
          'Chances come from a replay of the World Rugby rankings over every Test on record, the same way the app picks winners.',
          style: TextStyle(fontSize: 12, color: RaColors.faint),
        ),
      ]),
    );
  }
}

/// A card on Matchday that leads to the talking points: the biggest upset and the leading try scorer.
class TalkingPointsCard extends StatelessWidget {
  const TalkingPointsCard({super.key, required this.gender});

  final Gender gender;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final side = c.matchday!.side(gender);
    final moved = [for (final t in c.tournaments?.tournaments ?? <Tournament>[]) if (t.gender == gender && t.moves != null) t];
    final move = moved.isNotEmpty && moved.first.moves!.changes.isNotEmpty ? moved.first.moves!.changes.first : null;
    final lines = <String>[
      if (move != null) '${move.team}’s ${moved.first.name} title chance: ${move.before.round()}% → ${move.after.round()}%',
      if (side.upsets.isNotEmpty)
        'Upset of the year: ${side.upsets.first.winner} (given ${side.upsets.first.winnerChance}%)',
      if (side.hot.isNotEmpty) 'Top try scorer: ${side.hot.first.player}, ${side.hot.first.tries} in 12 months',
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Talking points'),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InsightsScreen(gender: gender))),
          child: Ink(
            decoration: cardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.insights, color: RaColors.gold, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final l in lines)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
              const Icon(Icons.chevron_right, color: RaColors.muted),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// The tournament a result belongs to, if the latest moves in its title race include it.
Tournament? tournamentMovedBy(AppController c, Gender gender, Result r) {
  for (final t in c.tournaments?.tournaments ?? <Tournament>[]) {
    if (t.gender == gender && (t.moves?.includes(r) ?? false)) return t;
  }
  return null;
}

