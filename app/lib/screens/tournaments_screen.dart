import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/world_cup_strip.dart';
import 'tournament_screen.dart';
import 'world_cup_screen.dart';

/// Every tournament we track for the chosen side, live ones first, with who
/// leads and (where there's a simulation) the title favourites.
class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  static String statusLabel(TournamentStatus s) => switch (s) {
        TournamentStatus.live => 'Live',
        TournamentStatus.next => 'Next',
        TournamentStatus.done => 'Final',
      };

  static String summary(Tournament t) {
    if (t.isSeries) {
      return '${t.results.length} Tests played${t.fixtures.isNotEmpty ? ' · ${t.fixtures.length} to come' : ''}';
    }
    final tops = [for (final g in t.groups) if (g.rows.isNotEmpty) g.rows.first.team];
    if (t.status == TournamentStatus.done) return 'Won by ${tops.first}';
    final fav = t.sim?.title.firstOrNull;
    final lead = tops.length > 1 ? 'Leaders: ${tops.join(' and ')}' : 'Leaders: ${tops.first}';
    return fav == null ? lead : '$lead · favourites ${fav.team} (${pct(fav.pct)})';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final t = c.tournaments;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Tournaments', style: displayStyle(22)),
        const SizedBox(height: 12),
        if (t == null)
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: RaColors.gold)))
        else ...[
          const WorldCupStrip(),
          const SizedBox(height: 12),
          GenderSwitch(value: c.gender, onChanged: c.setGender),
          const SectionTitle('Where things stand', eyebrow: 'Tournaments'),
          Container(
            decoration: cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: Column(children: [
                _row(
                  context,
                  title: c.gender == Gender.men ? 'Rugby World Cup 2027' : 'Women’s Rugby World Cup 2029',
                  sub: c.gender == Gender.men
                      ? 'Australia · starts in ${daysUntil(t.worldCup.firstKickOff)} days · 6 pools of 4'
                      : 'Australia · ${t.womensWorldCup.qualified.length} of ${t.womensWorldCup.teams} teams qualified',
                  status: 'Next',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorldCupScreen(initialGender: c.gender))),
                ),
                for (final x in t.forGender(c.gender))
                  _row(
                    context,
                    title: x.title,
                    sub: summary(x),
                    status: statusLabel(x.status),
                    live: x.status == TournamentStatus.live,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentScreen(id: x.id))),
                  ),
              ]),
            ),
          ),
          const FooterLinks(),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, {required String title, required String sub, required String status, bool live = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RaColors.line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            ]),
          ),
          const SizedBox(width: 8),
          Tag(status, strong: live),
          const Icon(Icons.chevron_right, color: RaColors.faint),
        ]),
      ),
    );
  }
}
