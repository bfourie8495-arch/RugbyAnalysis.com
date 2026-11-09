import 'package:flutter/material.dart';

import '../models/alerts.dart';
import '../models/feeds.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/club_tiles.dart';
import '../widgets/common.dart';
import 'chat_screen.dart' show askForName;

/// Your teams and your alerts.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key, this.standalone = false});

  final bool standalone; // opened from another screen, so it needs a back button

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final a = c.alerts;
    final list = ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      if (!standalone) Text('Your teams and alerts', style: displayStyle(22)),
      SectionTitle('Teams you follow', note: c.follows.length > 1 ? 'Tap ♡ to choose your team' : null),
      if (c.follows.isEmpty)
        const EmptyNote('No teams yet', 'Follow a team to see its games first and get its alerts.')
      else
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              for (final k in c.follows)
                _followRow(context, c, Gender.fromKey(k.substring(0, 1)), k.substring(2)),
            ]),
          ),
        ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: RaColors.line2)),
        onPressed: c.matchday == null ? null : () => _pickTeams(context),
        icon: const Icon(Icons.add),
        label: const Text('Add teams', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      if (c.clubFollows.isNotEmpty && c.clubs != null) ...[
        const SectionTitle('Clubs you follow'),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              for (final id in c.clubFollows)
                ListTile(
                  minTileHeight: 52,
                  leading: ClubBadge(c.clubs!.club(id), size: 30),
                  title: Text(c.clubs!.club(id).name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.clubs!.league(c.clubs!.club(id).league)?.short ?? '', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                  trailing: IconButton(tooltip: 'Stop following', onPressed: () => c.toggleClub(id), icon: const Icon(Icons.close, color: RaColors.faint)),
                  onTap: () => openClub(context, id),
                ),
            ]),
          ),
        ),
      ],
      const SectionTitle('Alerts'),
      if (!a.on)
        RaCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Alerts are off', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Turn them on for a heads-up before your teams play, and when the big games are on.', style: TextStyle(color: RaColors.muted)),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () async {
                final ok = await c.turnOnAlerts();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerts are blocked in your phone’s settings.')));
                }
              },
              child: const Text('Turn on alerts', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        )
      else ...[
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          // A Material of its own, so the rows' tap ripples show on the card.
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
            SwitchListTile(
              title: const Text('Weekend heads-up', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Thursday evening: this weekend’s games for you', style: TextStyle(fontSize: 12, color: RaColors.faint)),
              value: a.weekend,
              onChanged: (v) => c.setAlerts(a.copyWith(weekend: v)),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Big games', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Tests between two top-8 teams, followed or not', style: TextStyle(fontSize: 12, color: RaColors.faint)),
              value: a.bigGames,
              onChanged: (v) => c.setAlerts(a.copyWith(bigGames: v)),
            ),
            if (a.bigGames)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(spacing: 8, children: [
                  for (final g in Gender.values)
                    FilterChip(
                      label: Text('${g.label}’s Tests'),
                      selected: a.bigGamesFor.contains(g),
                      showCheckmark: false,
                      labelStyle: TextStyle(fontFamily: body, color: a.bigGamesFor.contains(g) ? RaColors.onGold : RaColors.ink, fontWeight: FontWeight.w700),
                      onSelected: (on) => c.setAlerts(a.copyWith(bigGamesFor: on ? {...a.bigGamesFor, g} : ({...a.bigGamesFor}..remove(g)))),
                    ),
                ]),
              ),
            const Divider(height: 1),
            const ListTile(
              title: Text('Kick-off reminder', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('For your teams, big games and match reminders. Never between 10pm and 7am.', style: TextStyle(fontSize: 12, color: RaColors.faint)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(spacing: 8, children: [
                for (final (mins, label) in [(0, 'Off'), (15, '15 min before'), (60, '1 hour before')])
                  ChoiceChip(
                    label: Text(label),
                    selected: a.kickoffMinutes == mins,
                    showCheckmark: false,
                    labelStyle: TextStyle(fontFamily: body, color: a.kickoffMinutes == mins ? RaColors.onGold : RaColors.ink, fontWeight: FontWeight.w700),
                    onSelected: (_) => c.setAlerts(a.copyWith(kickoffMinutes: mins)),
                  ),
              ]),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Full-time scores', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('For your teams and big games, once the website has the result', style: TextStyle(fontSize: 12, color: RaColors.faint)),
              value: a.fullTime,
              onChanged: (v) => c.setAlerts(a.copyWith(fullTime: v)),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Turn off all alerts', style: TextStyle(color: RaColors.muted)),
              onTap: () => c.setAlerts(a.copyWith(on: false)),
            ),
          ]),
          ),
        ),
        const SectionTitle('Your next heads-up'),
        _preview(c),
        if (c.backend == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('This copy of the app isn’t connected to its server yet, so alerts are saved here but not sent.',
                style: TextStyle(fontSize: 12, color: RaColors.faint)),
          ),
      ],
      if (c.chatAvailable && (c.myName != null || c.blocked.isNotEmpty)) ...[
        const SectionTitle('Chat'),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              ListTile(
                minTileHeight: 52,
                title: const Text('Your name in chat', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(c.myName ?? 'Not chosen yet', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                trailing: const Icon(Icons.edit_outlined, color: RaColors.faint),
                onTap: () => askForName(context, change: true),
              ),
              for (final uid in c.blocked)
                ListTile(
                  minTileHeight: 52,
                  title: const Text('Someone you hid', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_hiddenName(c, uid), style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                  trailing: TextButton(onPressed: () => c.unblock(uid), child: const Text('Show again')),
                ),
            ]),
          ),
        ),
      ],
      const SectionTitle('Your data'),
      RaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              c.backend == null
                  ? 'Your teams and alert settings are kept on this phone only.'
                  : 'The app keeps your teams, clubs, alert settings and this phone’s alert token under an anonymous ID, plus your chat name '
                      'and messages if you use chat (messages go after 30 days). No email or location.',
              style: const TextStyle(color: RaColors.muted)),
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 44)),
            onPressed: () => openLink('https://rugbyanalysis.com/privacy'),
            child: const Text('Privacy policy'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), side: const BorderSide(color: RaColors.line2)),
            onPressed: () => _confirmDelete(context, c),
            child: const Text('Delete my data', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      if (!standalone) const FooterLinks(),
    ]);
    if (!standalone) return list;
    return Scaffold(appBar: AppBar(title: const Text('Your teams and alerts')), body: list);
  }

  /// The name of someone you hid, from any room you share with them.
  static String _hiddenName(AppController c, String uid) {
    for (final r in c.rooms) {
      final n = r.names[uid];
      if (n != null) return n;
    }
    return 'No longer in your rooms';
  }

  Widget _followRow(BuildContext context, AppController c, Gender g, String team) {
    final k = followKey(g, team);
    final muted = c.alerts.muted.contains(k);
    final mine = c.isMyTeam(g, team);
    return ListTile(
      leading: TeamBadge(c.matchday?.nation(team) ?? Nation.unknown(team)),
      title: Text(team, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${mine ? 'Your team · ' : ''}${g.label} · ${muted ? 'alerts muted' : 'alerts on'}',
          style: TextStyle(fontSize: 12, color: mine ? RaColors.goldSoft : RaColors.faint, fontWeight: mine ? FontWeight.w700 : null)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: mine ? '$team is your team' : 'Make $team your team',
          icon: Icon(mine ? Icons.favorite : Icons.favorite_border, color: mine ? RaColors.gold : RaColors.faint),
          onPressed: mine ? null : () => c.makeMyTeam(g, team),
        ),
        IconButton(
          tooltip: muted ? 'Turn on alerts for $team' : 'Mute alerts for $team',
          icon: Icon(muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, color: muted ? RaColors.faint : RaColors.gold),
          onPressed: () {
            final m = {...c.alerts.muted};
            if (!m.remove(k)) m.add(k);
            c.setAlerts(c.alerts.copyWith(muted: m));
          },
        ),
        IconButton(tooltip: 'Unfollow $team', icon: const Icon(Icons.close, color: RaColors.faint), onPressed: () => c.toggleFollow(g, team)),
      ]),
    );
  }

  Widget _preview(AppController c) {
    final weekend = c.weekend();
    if (weekend.isEmpty) return const EmptyNote('Nothing to send yet', 'Follow a team or switch on big games.');
    final text = headsUpText(weekend);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RaColors.ink, borderRadius: BorderRadius.circular(18)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: RaColors.onGold, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.sports_rugby, color: RaColors.gold),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RugbyAnalysis · Thursday evening', style: TextStyle(fontSize: 12, color: Color(0xFF4A5873), fontWeight: FontWeight.w700)),
            Text(text.title, style: const TextStyle(fontWeight: FontWeight.w800, color: RaColors.onGold)),
            Text(text.body, style: const TextStyle(fontSize: 13, color: Color(0xFF24324B))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppController c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete your data?'),
        content: const Text('This removes your teams, clubs, alert settings and reminders from the app and its server, and turns alerts off. '
            'It also takes you out of your chat rooms, deletes your messages and deletes the rooms you made. It can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await c.deleteMyData();
      messenger.showSnackBar(const SnackBar(content: Text('Your data has been deleted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t reach the server. Check your connection and try again.')));
    }
  }

  Future<void> _pickTeams(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RaColors.page,
      builder: (_) => const _TeamPicker(),
    );
  }
}

/// A sheet listing the ranked nations to follow, men's or women's.
class _TeamPicker extends StatefulWidget {
  const _TeamPicker();

  @override
  State<_TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends State<_TeamPicker> {
  Gender? _g;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final g = _g ?? c.gender;
    final side = c.matchday!.side(g);
    final teams = [for (final r in side.ranked) if (_q.isEmpty || r.team.toLowerCase().contains(_q.toLowerCase())) r];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('Follow teams', style: displayStyle(18))),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ]),
            const SizedBox(height: 8),
            GenderSwitch(value: g, onChanged: (x) => setState(() => _g = x)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Search', border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => _q = v),
            ),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, children: [
            for (final r in teams)
              CheckboxListTile(
                secondary: TeamBadge(c.matchday!.nation(r.team)),
                title: Text(r.team),
                subtitle: Text('World No. ${r.position}', style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                value: c.isFollowing(g, r.team),
                onChanged: (_) => c.toggleFollow(g, r.team),
              ),
          ]),
        ),
      ]),
    );
  }
}
