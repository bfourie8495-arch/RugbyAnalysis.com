import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../screens/world_cup_screen.dart';
import '../state/app_controller.dart';
import '../theme.dart';

/// The next World Cup, always one tap away: a countdown, and your team's
/// opener if you follow one that's going. Women's side: the 2029 World Cup.
class WorldCupStrip extends StatelessWidget {
  const WorldCupStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final t = c.tournaments;
    if (t == null) return const SizedBox.shrink();
    final wc = t.worldCup;
    String title, sub, big, bigLabel;
    if (c.gender == Gender.women) {
      final w = t.womensWorldCup;
      final mine = c.followed(Gender.women);
      final hit = w.qualified.where((q) => mine.contains(q.team)).firstOrNull;
      title = 'Women’s Rugby World Cup 2029';
      sub = hit != null ? '${hit.team} are in, as ${hit.how.toLowerCase()}' : '${w.host} · ${w.teams} teams · dates to come';
      big = '2029';
      bigLabel = 'dates TBC';
    } else {
      if (wc.finished) return const SizedBox.shrink();
      final days = daysUntil(wc.firstKickOff);
      final live = days <= 0;
      final mine = c.followed(Gender.men).where((x) => wc.poolOf(x) != null).toList();
      final m = mine.isEmpty ? null : wc.firstMatchOf(mine.first);
      title = 'Rugby World Cup 2027 · ${wc.host}';
      sub = m == null
          ? '1 Oct to 13 Nov 2027'
          : '${mine.first} open v ${m.home == mine.first ? m.away : m.home}, ${dayLabel(m.kickOff.toLocal())}';
      big = live ? 'Live' : '$days';
      bigLabel = live ? 'now' : (days == 1 ? 'day' : 'days');
    }
    return Semantics(
      button: true,
      label: '$title. $sub. $big $bigLabel. Open the World Cup',
      excludeSemantics: true,
      child: Material(
        color: RaColors.cardHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF2F4A78))),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorldCupScreen(initialGender: c.gender))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Row(children: [
              const Icon(Icons.emoji_events_outlined, color: RaColors.gold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: displayStyle(13)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
                ]),
              ),
              Column(children: [
                Text(big, style: displayStyle(18, color: RaColors.gold, weight: FontWeight.w800)),
                Text(bigLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RaColors.muted)),
              ]),
              const Icon(Icons.chevron_right, color: RaColors.faint),
            ]),
          ),
        ),
      ),
    );
  }
}
