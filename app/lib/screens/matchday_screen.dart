import 'package:flutter/material.dart';

import '../models/alerts.dart';
import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/match_tiles.dart';
import '../widgets/world_cup_strip.dart';
import 'me_screen.dart';

/// The first tab: the World Cup strip, this weekend's games worth watching,
/// every upcoming Test with the model's pick, and the latest results.
class MatchdayScreen extends StatelessWidget {
  const MatchdayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: c.refresh,
      color: RaColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _Brand(),
          const SizedBox(height: 10),
          if (!c.ready) ..._loadingOrError(c) else ..._content(context, c),
        ],
      ),
    );
  }

  List<Widget> _loadingOrError(AppController c) => [
        const SizedBox(height: 80),
        if (c.error == null)
          const Center(child: CircularProgressIndicator(color: RaColors.gold))
        else
          EmptyNote('Nothing to show yet', c.error!),
      ];

  List<Widget> _content(BuildContext context, AppController c) {
    final g = c.gender;
    final side = c.matchday!.side(g);
    final weekend = c.weekend();
    final groups = <String, List<Fixture>>{};
    for (final f in side.fixtures.take(30)) {
      final label = f.kickOff == null ? dateLabel(f.date) : dayLabel(f.kickOff!.toLocal());
      (groups[label] ??= []).add(f);
    }
    return [
      const WorldCupStrip(),
      const SizedBox(height: 12),
      GenderSwitch(value: g, onChanged: c.setGender),
      const SectionTitle('This weekend', eyebrow: 'Worth watching'),
      if (weekend.isNotEmpty)
        TileList(children: [
          for (final w in weekend.take(6))
            FixtureTile(
              gender: w.gender,
              fixture: w.fixture,
              tag: Tag(switch (w.reason) { WatchReason.yourTeam => 'Your team', WatchReason.bigGame => 'Big game', WatchReason.reminder => 'Reminder' },
                  strong: w.reason == WatchReason.yourTeam),
            ),
        ])
      else
        RaCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeScreen(standalone: true))),
          child: const Row(children: [
            Icon(Icons.notifications_none, color: RaColors.gold),
            SizedBox(width: 12),
            Expanded(
              child: Text('Follow a team or switch on big games, and the games worth watching show up here.',
                  style: TextStyle(color: RaColors.muted)),
            ),
            Icon(Icons.chevron_right, color: RaColors.faint),
          ]),
        ),
      if (!c.alerts.on && weekend.isNotEmpty) ...[
        const SizedBox(height: 10),
        _AlertsCta(onTap: () async {
          final ok = await c.turnOnAlerts();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Alerts on. Your heads-up comes on Thursday evening.' : 'Alerts are blocked in your phone’s settings.')));
        }),
      ],
      SectionTitle('Up next', eyebrow: 'Matchday', note: side.fixtures.isEmpty ? null : '${side.fixtures.length} scheduled'),
      if (groups.isEmpty)
        EmptyNote('No ${g == Gender.men ? 'men’s' : 'women’s'} Tests scheduled', 'The latest results are below.')
      else
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
            child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: RaColors.muted)),
          ),
          TileList(children: [for (final f in e.value) FixtureTile(gender: g, fixture: f)]),
          const SizedBox(height: 8),
        ],
      const SectionTitle('Latest results'),
      TileList(children: [for (final r in side.results.take(10)) ResultTile(gender: g, result: r)]),
      const FooterLinks(),
    ];
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: RaColors.onGold, borderRadius: BorderRadius.circular(8), border: Border.all(color: RaColors.line2)),
        child: Transform.rotate(angle: -0.6, child: const Icon(Icons.sports_rugby, color: RaColors.gold, size: 22)),
      ),
      const SizedBox(width: 9),
      Text('RugbyAnalysis', style: displayStyle(19)),
    ]);
  }
}

class _AlertsCta extends StatelessWidget {
  const _AlertsCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RaColors.gold,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.notifications_active_outlined, color: RaColors.onGold),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Get a ping before each weekend',
                    style: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, color: RaColors.onGold, fontSize: 15)),
                Text('Who’s playing and when, for your teams and the big games.',
                    style: TextStyle(color: RaColors.onGold, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
