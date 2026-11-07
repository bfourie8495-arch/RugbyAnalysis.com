import 'package:flutter/material.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/stats.dart';
import 'team_screen.dart';

/// One Test. Before it: both teams, kick-off in your time, the model's pick and a kick-off reminder.
/// After it: the score, tries, kicks, cards and try scorers. Both: the head-to-head and how the two
/// teams compare over their last ten Tests.
class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key, required this.gender, required Fixture this.fixture}) : result = null;

  const MatchScreen.result({super.key, required this.gender, required Result this.result}) : fixture = null;

  final Gender gender;
  final Fixture? fixture;
  final Result? result;

  String get home => fixture?.home ?? result!.home;
  String get away => fixture?.away ?? result!.away;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.matchday!;
    final side = feed.side(gender);
    final f = fixture, r = result;
    final k = f?.kickOff?.toLocal();
    Widget team(String t) {
      final lost = r != null && r.winner != null && r.winner != t;
      return Expanded(
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(gender: gender, team: t))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              TeamBadge(feed.nation(t), size: 64),
              const SizedBox(height: 8),
              Text(t, textAlign: TextAlign.center, style: displayStyle(15, color: lost ? RaColors.muted : RaColors.ink)),
              Text(side.rankOf(t) == null ? 'Unranked' : 'World No. ${side.rankOf(t)}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            ]),
          ),
        ),
      );
    }

    final middle = r != null
        ? Column(children: [
            Text('${r.homeScore}–${r.awayScore}', style: displayStyle(30, weight: FontWeight.w800)),
            const Text('FULL TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: RaColors.faint)),
          ])
        : Column(children: [
            Text('VS', style: displayStyle(20, color: RaColors.faint, weight: FontWeight.w800)),
            Text(k == null ? 'TBC' : clock(k), style: displayStyle(17)),
          ]);
    final comp = f?.comp ?? r!.comp;
    final when = f != null ? (k == null ? dateLabel(f.date) : dayLabel(k)) : '${dateLabel(r!.date)} ${r.date.substring(0, 4)}';
    final venue = f?.venue ?? r?.detail?.ground ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(r != null ? 'Result' : 'Match preview')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        RaCard(
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              team(home),
              Padding(padding: const EdgeInsets.only(top: 22), child: middle),
              team(away),
            ]),
            const Divider(height: 22),
            if (comp.isNotEmpty) Text(comp, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('$when${venue.isEmpty ? '' : ' · $venue'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            if (f?.pick != null) ...[
              const Divider(height: 22),
              PickBar(home: f!.home, away: f.away, homeChance: f.pick!),
              const SizedBox(height: 6),
              const Text('RugbyAnalysis model · chance of winning', style: TextStyle(fontSize: 11, color: RaColors.faint)),
            ],
          ]),
        ),
        if (f != null) ...[const SizedBox(height: 12), _ReminderButton(gender: gender, fixture: f)],
        if (r != null) MatchStatsSection(result: r),
        HeadToHeadSection(gender: gender, first: home, second: away, skip: r),
        FormNumbersSection(gender: gender, first: home, second: away),
        if (f?.pick != null) ...[
          const SizedBox(height: 12),
          const Text(
            'The pick comes from each side’s World Rugby ranking points, with a small boost for a team playing at home.',
            style: TextStyle(fontSize: 12, color: RaColors.faint),
          ),
        ],
      ]),
    );
  }
}

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.gender, required this.fixture});

  final Gender gender;
  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final reminded = AppScope.of(context).hasReminder(gender, fixture);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: reminded ? RaColors.card : RaColors.gold,
        foregroundColor: reminded ? RaColors.ink : RaColors.onGold,
        minimumSize: const Size.fromHeight(50),
        side: reminded ? const BorderSide(color: RaColors.line2) : null,
      ),
      onPressed: () async {
        final added = await AppScope.read(context).toggleReminder(gender, fixture);
        if (!context.mounted) return;
        final mins = AppScope.read(context).alerts.kickoffMinutes;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(added ? 'Reminder set: we’ll ping you ${mins == 15 ? '15 minutes' : 'an hour'} before kick-off.' : 'Reminder removed.')));
      },
      icon: Icon(reminded ? Icons.notifications_active : Icons.notifications_none),
      label: Text(reminded ? 'Reminder set · tap to remove' : 'Remind me before kick-off', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
