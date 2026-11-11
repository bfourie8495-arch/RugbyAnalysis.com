import 'package:flutter/material.dart';

import '../models/clubs.dart';
import '../models/format.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/club_tiles.dart';
import '../widgets/common.dart';
import '../widgets/match_tiles.dart' show TileList;

/// The Clubs tab: your clubs and their next games, then one competition at a time (the same ten as the
/// website's clubs page) with its table, next fixtures and latest results.
class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String? _code; // the competition being shown; null = your first club's, or the URC

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.clubs;
    return RefreshIndicator(
      onRefresh: c.refresh,
      color: RaColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Clubs', style: displayStyle(22)),
          const SizedBox(height: 4),
          const Text('Ten competitions, from the URC to Japan’s League One.', style: TextStyle(color: RaColors.muted, fontSize: 13)),
          if (feed == null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: c.loading
                  ? const Center(child: CircularProgressIndicator(color: RaColors.gold))
                  : const EmptyNote('No club rugby yet', 'Couldn’t load the clubs. Pull down to try again.'),
            )
          else
            ..._content(context, c, feed),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppController c, ClubsFeed feed) {
    final mine = [for (final id in c.clubFollows) if (feed.clubs.containsKey(id)) feed.club(id)];
    final fallback = mine.isNotEmpty ? mine.first.league : 'URC';
    final league = feed.league(_code ?? fallback) ?? feed.leagues.first;
    return [
      if (mine.isNotEmpty) ...[
        const SectionTitle('Your clubs', eyebrow: 'Following'),
        TileList(children: [for (final club in mine) _YourClubRow(club: club)]),
      ],
      const SectionTitle('Competitions'),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final l in feed.leagues)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(l.short),
                  selected: l.code == league.code,
                  showCheckmark: false,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: l.code == league.code ? RaColors.onGold : RaColors.ink),
                  onSelected: (_) => setState(() => _code = l.code),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LeagueView(league: league),
      const FooterLinks(),
    ];
  }
}

/// One of your clubs: its form, where it sits and its next game.
class _YourClubRow extends StatelessWidget {
  const _YourClubRow({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    final feed = AppScope.of(context).clubs!;
    final pos = feed.league(club.league)?.positionOf(club.id);
    final next = club.fixtures.firstOrNull;
    final opp = next == null ? null : feed.club(next.home == club.id ? next.away : next.home);
    final when = next == null ? 'No games listed yet' : '${next.home == club.id ? 'v' : 'at'} ${opp!.name} · ${_day(next)}';
    return InkWell(
      onTap: () => openClub(context, club.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          ClubBadge(club, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(club.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text([if (pos != null) '${ordinal(pos)} in the ${feed.league(club.league)!.short}', when].join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
            ]),
          ),
          if (club.form.isNotEmpty) ...[const SizedBox(width: 8), FormDots(club.form)],
        ]),
      ),
    );
  }

  static String _day(ClubGame g) {
    final k = g.kickOff?.toLocal();
    if (k == null) return dateLabel(g.date);
    return '${kickOffDay(k)} ${clock(k)}';
  }
}

/// A competition: what it is, its table (or last season's, before this one starts), next fixtures and results.
class LeagueView extends StatelessWidget {
  const LeagueView({super.key, required this.league});

  final ClubLeague league;

  @override
  Widget build(BuildContext context) {
    final l = league;
    final lastSeason = l.tableSeason.isNotEmpty && l.tableSeason != l.season;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: l.background,
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: l.accent, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l.season} · ${l.where}'.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: l.light)),
          const SizedBox(height: 4),
          Text(l.name, style: displayStyle(20, color: Colors.white)),
          // where it's at, in one sentence, before how it works
          if (leagueIdea(l, (id) => AppScope.of(context).clubs!.club(id).name) case final idea?) ...[
            const SizedBox(height: 8),
            Text(idea, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700, height: 1.35)),
          ],
          if (l.how.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.how, style: const TextStyle(fontSize: 13, color: Color(0xFFE6E9F0), height: 1.4)),
          ],
        ]),
      ),
      if (l.table.isNotEmpty) ...[
        SectionTitle(lastSeason ? 'Last season’s table' : 'Table', note: lastSeason ? l.tableSeason : null),
        Container(decoration: cardDecoration(), clipBehavior: Clip.antiAlias, child: Material(color: Colors.transparent, child: ClubTable(league: l))),
      ],
      SectionTitle('Next games', note: l.fixtures.isEmpty ? null : 'Your time'),
      if (l.fixtures.isEmpty)
        EmptyNote('No games to come', l.started ? 'The ${l.season} season is over.' : 'The fixtures aren’t out yet.')
      else
        TileList(children: [for (final g in l.fixtures) ClubGameTile(game: g, showComp: false)]),
      if (l.results.isNotEmpty) ...[
        const SectionTitle('Latest results'),
        TileList(children: [for (final g in l.results) ClubGameTile(game: g, showComp: false)]),
      ],
    ]);
  }
}
