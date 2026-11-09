import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/chat.dart';
import '../models/clubs.dart';
import '../models/feeds.dart';
import '../models/format.dart';
import '../screens/chat_screen.dart' show startRoom;
import '../screens/match_screen.dart';
import '../screens/room_screen.dart' show openRoom;
import '../state/app_controller.dart';
import '../theme.dart';
import 'club_tiles.dart';
import 'common.dart';
import 'match_tiles.dart' show KickOffBlock;
import 'stats.dart' show openResult;

/// 'South Africa v Italy', or 'Leinster v Munster' for a club game.
String matchTitle(AppController c, PinnedMatch m) {
  String name(String t) => m.isClub ? (c.clubs?.club(t).name ?? t) : t;
  return '${name(m.home)} v ${name(m.away)}';
}

/// A room's picture: the pinned match's two badges, or its first letter.
class RoomAvatar extends StatelessWidget {
  const RoomAvatar({super.key, required this.room, this.size = 42});

  final Room room;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final m = room.match;
    Widget badge(String t, double s) => m!.isClub
        ? (c.clubs == null ? _letter(t, s) : ClubBadge(c.clubs!.club(t), size: s))
        : (c.matchday == null ? _letter(t, s) : TeamBadge(c.matchday!.nation(t), size: s));
    if (m != null) {
      final s = size * 0.66;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          Positioned(left: 0, top: 0, child: badge(m.home, s)),
          Positioned(right: 0, bottom: 0, child: badge(m.away, s)),
        ]),
      );
    }
    return _letter(room.name, size);
  }

  Widget _letter(String s, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: RaColors.cardHi, shape: BoxShape.circle),
        child: Text(s.isEmpty ? '?' : s.characters.first.toUpperCase(),
            style: displayStyle(size * 0.42, color: RaColors.gold)),
      );
}

/// The match a room is watching: both teams, then the kick-off (to come) or the score (once it's in).
/// Tapping it opens the match (Tests) or the home club. [onClear] shows an × to unpin it.
class PinnedMatchCard extends StatelessWidget {
  const PinnedMatchCard({super.key, required this.match, this.onClear});

  final PinnedMatch match;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final m = match;
    int? hs, as_;
    Fixture? fixture;
    Result? result;
    VoidCallback? open;
    if (m.isClub) {
      final feed = c.clubs;
      final game = feed == null ? null : _clubGame(feed, m);
      hs = game?.homeScore;
      as_ = game?.awayScore;
      if (feed != null) open = () => openClub(context, m.home);
    } else if (c.matchday != null) {
      final side = c.matchday!.side(m.gender);
      result = side.results.where((r) => r.date == m.date && r.home == m.home && r.away == m.away).firstOrNull;
      fixture = side.fixtures.where((f) => f.home == m.home && f.away == m.away && f.date == m.date).firstOrNull;
      hs = result?.homeScore;
      as_ = result?.awayScore;
      if (result != null) {
        open = () => openResult(context, m.gender, result!);
      } else if (fixture != null) {
        open = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(gender: m.gender, fixture: fixture!)));
      }
    }
    Widget team(String t, int? score, int? other) {
      final lost = score != null && other != null && score < other;
      final badge = m.isClub
          ? (c.clubs == null ? const SizedBox(width: 24) : ClubBadge(c.clubs!.club(t), size: 24))
          : (c.matchday == null ? const SizedBox(width: 24) : TeamBadge(c.matchday!.nation(t), size: 24));
      return Row(children: [
        badge,
        const SizedBox(width: 10),
        Expanded(
          child: Text(m.isClub ? (c.clubs?.club(t).name ?? t) : t,
              overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: lost ? RaColors.muted : RaColors.ink)),
        ),
        if (score != null) Text('$score', style: displayStyle(18, color: lost ? RaColors.faint : RaColors.ink)),
      ]);
    }

    final comp = m.isClub ? (c.clubs?.league(m.comp)?.short ?? m.comp) : m.comp;
    return Container(
      decoration: cardDecoration(color: RaColors.cardHi, border: RaColors.gold.withValues(alpha: 0.5)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.push_pin, size: 14, color: RaColors.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(['WATCHING', if (comp.isNotEmpty) comp.toUpperCase()].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: RaColors.gold)),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Unpin this match',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 18, color: RaColors.faint),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Column(children: [team(m.home, hs, as_), const SizedBox(height: 6), team(m.away, as_, hs)])),
                  if (hs == null) ...[
                    const SizedBox(width: 12),
                    KickOffBlock(fixture: fixture ?? Fixture(date: m.date, home: m.home, away: m.away, kickOff: m.kickOff)),
                  ] else ...[
                    const SizedBox(width: 12),
                    const Text('FULL\nTIME', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: RaColors.faint)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static ClubGame? _clubGame(ClubsFeed feed, PinnedMatch m) {
    bool same(ClubGame g) => g.date == m.date && g.home == m.home && g.away == m.away;
    final home = feed.clubs[m.home];
    if (home != null) {
      for (final g in [...home.results, ...home.fixtures]) {
        if (same(g)) return g;
      }
    }
    return null;
  }
}

/// The invite: the code in big letters, Share (to WhatsApp and the like) and Copy.
Future<void> showInvite(BuildContext context, Room room) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: RaColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        final c = AppScope.read(context);
        final text = inviteMessage(room, c.myName ?? 'A friend');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Invite friends to ${room.name}', style: displayStyle(18)),
              const SizedBox(height: 6),
              const Text('Send them the link. With the app, it opens the room; without it, it takes them to Google Play. '
                  'Anyone with the link or code can join, so only send it to people you know.',
                  style: TextStyle(color: RaColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: cardDecoration(color: RaColors.page),
                child: Column(children: [
                  const Text('ROOM CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: RaColors.faint)),
                  const SizedBox(height: 4),
                  SelectableText(spacedCode(room.id), style: displayStyle(24, color: RaColors.gold, weight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  try {
                    await SharePlus.instance.share(ShareParams(text: text, subject: 'Join ${room.name} on RugbyAnalysis'));
                  } catch (_) {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (sheet.mounted) {
                      ScaffoldMessenger.of(sheet).showSnackBar(const SnackBar(content: Text('Invite copied. Paste it to your friends.')));
                    }
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('Share the invite', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: RaColors.line2)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (sheet.mounted) Navigator.of(sheet).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite copied. Paste it to your friends.')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy the invite', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
      },
    );

/// Games you might watch together: Tests and club games in the next week (live ones too), soonest first.
/// Your teams and clubs come first.
List<PinnedMatch> upcomingToPin(AppController c, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toUtc();
  final until = n.add(const Duration(days: 8));
  bool soon(DateTime? k, String date) {
    final t = k ?? DateTime.tryParse(date);
    return t != null && t.isAfter(n.subtract(const Duration(hours: 3))) && t.isBefore(until);
  }

  final out = <PinnedMatch>[];
  final md = c.matchday;
  if (md != null) {
    for (final g in Gender.values) {
      for (final f in md.side(g).fixtures) {
        if (soon(f.kickOff, f.date) && (!c.isMinorTest(g, f.home, f.away) || c.showAllTests)) out.add(PinnedMatch.test(g, f));
      }
    }
  }
  final cf = c.clubs;
  if (cf != null) {
    for (final l in cf.leagues) {
      for (final f in l.fixtures) {
        if (soon(f.kickOff, f.date)) out.add(PinnedMatch.club(f, comp: l.code));
      }
    }
  }
  int rank(PinnedMatch m) => m.isClub
      ? (c.isFollowingClub(m.home) || c.isFollowingClub(m.away) ? 0 : 1)
      : (c.isFollowing(m.gender, m.home) || c.isFollowing(m.gender, m.away) ? 0 : 1);
  DateTime when(PinnedMatch m) => m.kickOff ?? DateTime.tryParse(m.date) ?? n;
  final seen = <String>{};
  final unique = [for (final m in out) if (seen.add(m.key)) m];
  unique.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : when(a).compareTo(when(b));
  });
  return unique;
}

/// Pick the match a room is watching. Returns it, or null if you close the sheet.
Future<PinnedMatch?> pickMatch(BuildContext context) => showModalBottomSheet<PinnedMatch>(
      context: context,
      backgroundColor: RaColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        final c = AppScope.read(context);
        final games = upcomingToPin(c);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Text('Which match are you watching?', style: displayStyle(18)),
            const SizedBox(height: 4),
            const Text('Tests and club games in the next week. Everyone in the room sees the score.',
                style: TextStyle(color: RaColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            if (games.isEmpty)
              const EmptyNote('Nothing on this week', 'There are no Tests or club games in the next eight days.')
            else
              for (final m in games)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  title: Text(matchTitle(c, m), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_pickLine(c, m), style: const TextStyle(fontSize: 12, color: RaColors.faint)),
                  trailing: const Icon(Icons.push_pin_outlined, color: RaColors.gold),
                  onTap: () => Navigator.of(sheet).pop(m),
                ),
          ]),
        );
      },
    );

String _pickLine(AppController c, PinnedMatch m) {
  final k = m.kickOff?.toLocal();
  final when = k == null ? dateLabel(m.date) : '${kickOffDay(k)} ${clock(k)}';
  final what = m.isClub ? (c.clubs?.league(m.comp)?.short ?? m.comp) : (m.comp.isEmpty ? '${m.gender.label}’s Test' : m.comp);
  return '$when · $what';
}

/// "Watch with friends": pins [match] in one of your rooms (or a new one) and opens it.
Future<void> watchWithFriends(BuildContext context, PinnedMatch match) async {
  final c = AppScope.read(context);
  if (!c.chatAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat needs a connection to our server. Try again in a moment.')));
    return;
  }
  if (c.rooms.isEmpty) return startRoom(context, match: match);
  final pick = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: RaColors.card,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        Text('Watch ${matchTitle(c, match)} with…', style: displayStyle(18)),
        const SizedBox(height: 8),
        for (final r in c.rooms)
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: RoomAvatar(room: r, size: 36),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(r.peopleLine(c.myUid ?? ''), style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            onTap: () => Navigator.of(sheet).pop(r.id),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 56,
          leading: const CircleAvatar(radius: 18, backgroundColor: RaColors.cardHi, child: Icon(Icons.add, color: RaColors.gold)),
          title: const Text('A new room', style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.of(sheet).pop(''),
        ),
      ]),
    ),
  );
  if (pick == null || !context.mounted) return;
  if (pick.isEmpty) return startRoom(context, match: match);
  final room = c.room(pick);
  if (room == null) return;
  try {
    await c.pinMatch(room, match);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t pin the match. Check your connection.')));
    }
    return;
  }
  if (context.mounted) await openRoom(context, room.id);
}
