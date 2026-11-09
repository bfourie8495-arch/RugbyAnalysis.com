import 'package:flutter/material.dart';

import '../models/alerts.dart';
import '../models/clubs.dart';
import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/club_tiles.dart';
import '../widgets/common.dart';
import '../widgets/match_tiles.dart';
import '../widgets/world_cup_strip.dart';
import 'insights_screen.dart';
import 'me_screen.dart';

/// The first tab: the World Cup strip, this weekend's games worth watching,
/// every upcoming Test with the model's pick, and the latest results.
class MatchdayScreen extends StatelessWidget {
  const MatchdayScreen({super.key});

  /// The next game of each club you follow, in the next eight days, soonest first.
  static List<ClubGame> _clubGames(AppController c) {
    final feed = c.clubs;
    if (feed == null) return const [];
    final until = DateTime.now().add(const Duration(days: 8)).toIso8601String().substring(0, 10);
    final seen = <String>{};
    final out = <ClubGame>[];
    for (final id in c.clubFollows) {
      final next = feed.clubs[id]?.fixtures.firstOrNull;
      if (next != null && next.date.compareTo(until) <= 0 && seen.add(next.key)) out.add(next);
    }
    out.sort((a, b) => (a.kickOff?.toIso8601String() ?? a.date).compareTo(b.kickOff?.toIso8601String() ?? b.date));
    return out;
  }

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
    // Your team's games lead the weekend list; the rest stay in kick-off order.
    final all = c.weekend();
    bool mine(WatchItem w) => w.reason == WatchReason.yourTeam && w.team != null && c.isMyTeam(w.gender, w.team!);
    final weekend = [...all.where(mine), ...all.where((w) => !mine(w))];
    // Tests between smaller nations are hidden unless you ask for them.
    final fixtures = [for (final f in side.fixtures) if (c.showAllTests || !c.isMinorTest(g, f.home, f.away)) f];
    final hidden = side.fixtures.length - fixtures.length;
    final results = [for (final r in side.results) if (c.showAllTests || !c.isMinorTest(g, r.home, r.away)) r];
    final groups = <String, List<Fixture>>{};
    for (final f in fixtures.take(30)) {
      final k = f.kickOff?.toLocal();
      final day = k == null ? dateLabel(f.date) : kickOffDay(k);
      final label = k == null || day == dayLabel(k) ? day : '$day · ${dayLabel(k)}';
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
              tag: Tag(
                  switch (w.reason) {
                    WatchReason.yourTeam => mine(w) ? 'Your team' : 'You follow',
                    WatchReason.bigGame => 'Big game',
                    WatchReason.reminder => 'Reminder',
                  },
                  strong: mine(w)),
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
      if (_clubGames(c) case final games when games.isNotEmpty) ...[
        const SectionTitle('Your clubs', eyebrow: 'Next games', note: 'Your time'),
        TileList(children: [for (final g in games) ClubGameTile(game: g)]),
      ],
      SectionTitle('Up next', eyebrow: 'Matchday', note: fixtures.isEmpty ? null : '${fixtures.length} scheduled'),
      if (groups.isEmpty)
        EmptyNote('No ${g == Gender.men ? 'men’s' : 'women’s'} Tests scheduled', 'The latest results are below.')
      else
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
            child: Text(e.key,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: e.key.startsWith('Today') ? RaColors.gold : RaColors.ink)),
          ),
          TileList(children: [for (final f in e.value) FixtureTile(gender: g, fixture: f)]),
          const SizedBox(height: 8),
        ],
      if (hidden > 0 || c.showAllTests)
        _ShowAllButton(
          showingAll: c.showAllTests,
          hidden: hidden,
          onTap: () => c.setShowAllTests(!c.showAllTests),
        ),
      TalkingPointsCard(gender: g),
      const SectionTitle('Latest results'),
      TileList(children: [for (final r in results.take(10)) ResultTile(gender: g, result: r)]),
      const FooterLinks(),
    ];
  }
}

/// "Show all Tests" under Up next: the smaller nations' Tests are a tap away, but not in the way.
class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({required this.showingAll, required this.hidden, required this.onTap});

  final bool showingAll;
  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: RaColors.muted),
      onPressed: onTap,
      icon: Icon(showingAll ? Icons.filter_list : Icons.expand_more, size: 20),
      label: Text(
        showingAll
            ? 'Show only Tests with a top-${AppController.minorCutoff} team or yours'
            : 'Show all Tests ($hidden more between smaller nations)',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const BrandMark(size: 32),
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
