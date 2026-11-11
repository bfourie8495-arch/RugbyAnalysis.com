import 'package:flutter/material.dart';

import '../models/clubs.dart';
import '../models/format.dart';
import '../models/site_links.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/club_tiles.dart';
import '../widgets/common.dart';
import '../widgets/match_tiles.dart' show TileList;

/// A club: follow it, its form, where it sits in its league, its next games and latest results
/// in every competition it plays in.
class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final feed = c.clubs!;
    final club = feed.club(id);
    final league = feed.league(club.league);
    final pos = league?.positionOf(id);
    final row = pos == null ? null : league!.table[pos - 1];
    final following = c.isFollowingClub(id);
    final where = [club.city, club.country].where((s) => s.isNotEmpty).join(', ');
    return Scaffold(
      appBar: AppBar(title: Text(league?.short ?? 'Club')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: club.primary, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClubBadge(club, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (where.isNotEmpty)
                    Text(where.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: club.onPrimary)),
                  Text(club.name, style: displayStyle(24, color: club.onPrimary, weight: FontWeight.w800)),
                  if (pos != null && league != null)
                    Text('${ordinal(pos)} in the ${league.short}${league.tableSeason != league.season ? ' last season' : ''}',
                        style: TextStyle(color: club.onPrimary)),
                ]),
              ),
            ]),
            // the one sentence to take away, as on the website's club page
            if (clubIdea(club, league) case final idea?) ...[
              const SizedBox(height: 12),
              Text(idea, style: TextStyle(color: club.onPrimary, fontWeight: FontWeight.w600, height: 1.35)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: club.onPrimary, foregroundColor: club.primary, minimumSize: const Size.fromHeight(44)),
                onPressed: () => c.toggleClub(id),
                icon: Icon(following ? Icons.star : Icons.star_border),
                label: Text(following ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        if (league != null) ...[
          const SizedBox(height: 10),
          WebsiteButton(label: 'Full club page on the website', url: siteClubUrl(league, id)),
        ],
        if (club.form.isNotEmpty || row != null) ...[
          const SectionTitle('Form'),
          RaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (club.form.isNotEmpty)
                Row(children: [
                  const Expanded(child: Text('Last five games', style: TextStyle(color: RaColors.muted))),
                  FormDots(club.form),
                ]),
              if (row != null) ...[
                if (club.form.isNotEmpty) const SizedBox(height: 12),
                Row(children: [
                  _stat('${row.won}-${row.drawn}-${row.lost}', 'Won-drawn-lost'),
                  _stat(signed(row.diff), 'Points difference'),
                  _stat('${row.points}', 'League points', point: true),
                ]),
              ],
            ]),
          ),
        ],
        const SectionTitle('Next games', note: 'Your time'),
        if (club.fixtures.isEmpty)
          const EmptyNote('No games listed', 'The next fixtures aren’t out yet.')
        else
          TileList(children: [for (final g in club.fixtures) ClubGameTile(game: g, focus: id)]),
        if (club.results.isNotEmpty) ...[
          const SectionTitle('Latest results'),
          TileList(children: [for (final g in club.results) ClubGameTile(game: g, focus: id)]),
        ],
        if (league != null && league.table.isNotEmpty) ...[
          SectionTitle(league.name, note: league.tableSeason),
          Container(
            decoration: cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Material(color: Colors.transparent, child: ClubTable(league: league, highlight: id, compact: true)),
          ),
        ],
      ]),
    );
  }

  // gold only for league points, the number the table is decided on
  Widget _stat(String value, String label, {bool point = false}) => Expanded(
        child: Column(children: [
          Text(value, style: displayStyle(20, color: point ? RaColors.gold : RaColors.ink)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: RaColors.faint)),
        ]),
      );
}
