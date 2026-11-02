import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'team_screen.dart';

/// A match preview: both teams, kick-off in your time, the model's pick, form
/// and rankings, and a one-off kick-off reminder.
class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key, required this.gender, required this.fixture});

  final Gender gender;
  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final side = feed.side(gender);
    final f = fixture;
    final k = f.kickOff?.toLocal();
    final reminded = c.hasReminder(gender, f);
    Widget team(String t) => Expanded(
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(gender: gender, team: t))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                TeamBadge(feed.nation(t), size: 64),
                const SizedBox(height: 8),
                Text(t, textAlign: TextAlign.center, style: displayStyle(15)),
                Text(side.rankOf(t) == null ? 'Unranked' : 'World No. ${side.rankOf(t)}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Match preview')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        RaCard(
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              team(f.home),
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Column(children: [
                  Text('VS', style: displayStyle(20, color: RaColors.faint, weight: FontWeight.w800)),
                  Text(k == null ? 'TBC' : clock(k), style: displayStyle(17)),
                ]),
              ),
              team(f.away),
            ]),
            const Divider(height: 22),
            Text(f.comp, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${k == null ? dateLabel(f.date) : dayLabel(k)}${f.venue.isEmpty ? '' : ' · ${f.venue}'}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            if (f.pick != null) ...[
              const Divider(height: 22),
              PickBar(home: f.home, away: f.away, homeChance: f.pick!),
              const SizedBox(height: 6),
              const Text('RugbyAnalysis model · chance of winning', style: TextStyle(fontSize: 11, color: RaColors.faint)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: reminded ? RaColors.card : RaColors.gold,
            foregroundColor: reminded ? RaColors.ink : RaColors.onGold,
            minimumSize: const Size.fromHeight(50),
            side: reminded ? const BorderSide(color: RaColors.line2) : null,
          ),
          onPressed: () async {
            final added = await AppScope.read(context).toggleReminder(gender, f);
            if (!context.mounted) return;
            final mins = AppScope.read(context).alerts.kickoffMinutes;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(added ? 'Reminder set: we’ll ping you ${mins == 15 ? '15 minutes' : 'an hour'} before kick-off.' : 'Reminder removed.')));
          },
          icon: Icon(reminded ? Icons.notifications_active : Icons.notifications_none),
          label: Text(reminded ? 'Reminder set · tap to remove' : 'Remind me before kick-off', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SectionTitle('Form', note: 'Last 5 Tests'),
        RaCard(
          child: Column(children: [
            for (final t in [f.home, f.away])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  TeamBadge(feed.nation(t), size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600))),
                  FormDots(side.form[t] ?? ''),
                ]),
              ),
          ]),
        ),
        if (f.pick != null) ...[
          const SizedBox(height: 10),
          const Text(
            'The pick comes from each side’s World Rugby ranking points, with a small boost for a team playing at home.',
            style: TextStyle(fontSize: 12, color: RaColors.faint),
          ),
        ],
      ]),
    );
  }
}
