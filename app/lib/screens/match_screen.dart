import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/feeds.dart';
import '../models/chat.dart' show PinnedMatch;
import '../models/format.dart';
import '../models/site_links.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/chat_widgets.dart' show watchWithFriends;
import '../widgets/common.dart';
import '../widgets/insights.dart';
import '../widgets/match_tiles.dart';
import '../widgets/stats.dart';
import 'insights_screen.dart';
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
        : KickOffBlock(fixture: f!, large: true);
    final comp = f?.comp ?? r!.comp;
    final when = f != null ? (k == null ? dateLabel(f.date) : '${dayLabel(k)} · ${clock(k)} your time') : '${dateLabel(r!.date)} ${r.date.substring(0, 4)}';
    final venue = f?.venue ?? r?.detail?.ground ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(r != null ? 'Result' : 'Match preview'), actions: [
        // Text only: the pick before the game, the score after it, with a link to the head-to-head.
        // Kept in the top bar, apart from "Watch with friends" (which invites people into a chat room).
        IconButton(
          tooltip: r != null ? 'Share the score' : 'Share the pick',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => SharePlus.instance.share(ShareParams(text: shareText(gender, fixture: f, result: r))),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        RaCard(
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              team(home),
              Padding(padding: const EdgeInsets.only(top: 14), child: middle),
              team(away),
            ]),
            const Divider(height: 22),
            if (comp.isNotEmpty) Text(comp, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(when, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RaColors.ink)),
            if (venue.isNotEmpty) Text(venue, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: RaColors.muted)),
            if (f?.pick != null) ...[
              const Divider(height: 22),
              PickBar(home: f!.home, away: f.away, homeChance: f.pick!),
              const SizedBox(height: 6),
              const Text('RugbyAnalysis model · chance of winning', style: TextStyle(fontSize: 11, color: RaColors.faint)),
            ],
            if (r != null) UpsetLine(result: r),
          ]),
        ),
        if (f != null) ...[
          const SizedBox(height: 12),
          _ReminderButton(gender: gender, fixture: f),
          if (c.chatAvailable) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: RaColors.line2)),
              onPressed: () => watchWithFriends(context, PinnedMatch.test(gender, f)),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Watch with friends', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
        if (r != null) MatchStatsSection(result: r),
        if (r == null ? null : tournamentMovedBy(c, gender, r) case final t?) TitleMovesSection(tournament: t, title: 'What this round did'),
        HeadToHeadSection(gender: gender, first: home, second: away, skip: r),
        const SizedBox(height: 10),
        WebsiteButton(label: 'Full head to head on the website', url: siteH2hUrl(gender, home, away)),
        OppositionSection(gender: gender, first: home, second: away),
        FormNumbersSection(gender: gender, first: home, second: away),
        GroundAndRefereeSection(
            gender: gender, home: home, away: away, ground: f?.atGround ?? r?.atGround, referee: r?.withReferee, past: r != null),
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
