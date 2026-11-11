import 'dart:ui' show Color;

import 'feeds.dart' show Gender;
import 'format.dart' show ordinal;

// The club feed (rugbyanalysis.com/app/clubs.json, built by pipeline/build_app_clubs.py): ten club
// competitions with their current table, latest results and next fixtures, and every club's form and games.

String _s(Object? x) => x == null ? '' : '$x';
int? _i(Object? x) => x is num ? x.toInt() : null;
List<Object?> _l(Object? x) => x is List ? x : const [];
Map<String, dynamic> _m(Object? x) => x is Map ? x.cast<String, dynamic>() : const {};

Color _colour(Object? hex, Color fallback) {
  final h = _s(hex).replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  return v == null || h.length != 6 ? fallback : Color(0xFF000000 | v);
}

/// One club game. Kick-off times are UTC ([kickOff]); show them with toLocal().
class ClubGame {
  ClubGame({required this.date, required this.home, required this.away, this.homeScore, this.awayScore, this.kickOff, this.venue = '', this.round, this.comp = ''});

  factory ClubGame.fromJson(Map<String, dynamic> j) => ClubGame(
        date: _s(j['d']),
        home: _s(j['h']),
        away: _s(j['a']),
        homeScore: _i(j['hs']),
        awayScore: _i(j['as']),
        kickOff: j['ko'] is String ? DateTime.tryParse(j['ko'] as String) : null,
        venue: _s(j['v']),
        round: _i(j['r']),
        comp: _s(j['c']),
      );

  final String date; // yyyy-mm-dd
  final String home; // club ids
  final String away;
  final int? homeScore;
  final int? awayScore;
  final DateTime? kickOff;
  final String venue;
  final int? round;
  final String comp; // competition code, on a club's own list of games

  bool get played => homeScore != null && awayScore != null;
  bool involves(String club) => home == club || away == club;
  String get key => '$date|$home|$away';

  /// 'W', 'D' or 'L' for [club], or '' before it's played.
  String resultFor(String club) {
    if (!played) return '';
    final my = club == home ? homeScore! : awayScore!, op = club == home ? awayScore! : homeScore!;
    return my > op ? 'W' : my < op ? 'L' : 'D';
  }
}

/// A row of a club table: played, won, drawn, lost, points for and against, bonus points, points.
class ClubRow {
  ClubRow(this.club, this.played, this.won, this.drawn, this.lost, this.pointsFor, this.pointsAgainst, this.bonus, this.points);

  static ClubRow? fromJson(Object? x) {
    final r = _l(x);
    if (r.length < 9) return null;
    int n(int i) => _i(r[i]) ?? 0;
    return ClubRow(_s(r[0]), n(1), n(2), n(3), n(4), n(5), n(6), n(7), n(8));
  }

  final String club;
  final int played, won, drawn, lost, pointsFor, pointsAgainst, bonus, points;
  int get diff => pointsFor - pointsAgainst;
}

class ClubLeague {
  ClubLeague.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        code = _s(j['code']),
        name = _s(j['name']),
        short = _s(j['short']),
        gender = j['g'] == 'w' ? Gender.women : Gender.men,
        background = _colour(_l(j['colours']).elementAtOrNull(0), const Color(0xFF14243D)),
        accent = _colour(_l(j['colours']).elementAtOrNull(1), const Color(0xFFC9A24B)),
        light = _colour(_l(j['colours']).elementAtOrNull(2), const Color(0xFFE2C47C)),
        where = _s(j['where']),
        playoff = _i(j['playoff']) ?? 0,
        isCup = j['cup'] == true,
        how = _s(j['how']),
        season = _s(j['season']),
        started = j['started'] == true,
        tableSeason = _s(j['tableSeason']),
        table = [for (final r in _l(j['table'])) if (ClubRow.fromJson(r) case final row?) row],
        results = [for (final g in _l(j['results'])) ClubGame.fromJson(_m(g))],
        fixtures = [for (final g in _l(j['fixtures'])) ClubGame.fromJson(_m(g))];

  final String id; // 'urc'
  final String code; // 'URC', as on a club's games
  final String name;
  final String short;
  final Gender gender;
  final Color background, accent, light;
  final String where; // 'Ireland, Scotland, Wales, Italy and South Africa'
  final int playoff; // how many make the play-offs (0 for none or a cup)
  final bool isCup;
  final String how;
  final String season; // '2026–27'
  final bool started; // any games played this season
  final String tableSeason; // the season [table] is from (last season's, before this one starts)
  final List<ClubRow> table;
  final List<ClubGame> results; // newest first
  final List<ClubGame> fixtures; // soonest first

  int? positionOf(String club) {
    for (var i = 0; i < table.length; i++) {
      if (table[i].club == club) return i + 1;
    }
    return null;
  }
}

class Club {
  Club.fromJson(this.id, Map<String, dynamic> j)
      : name = _s(j['name']),
        code = _s(j['code']),
        league = _s(j['lg']),
        country = _s(j['country']),
        city = _s(j['city']),
        primary = _colour(_l(j['colours']).elementAtOrNull(0), const Color(0xFF14243D)),
        onPrimary = _colour(_l(j['colours']).elementAtOrNull(1), const Color(0xFFFFFFFF)),
        form = _s(j['form']),
        results = [for (final g in _l(j['results'])) ClubGame.fromJson(_m(g))],
        fixtures = [for (final g in _l(j['fixtures'])) ClubGame.fromJson(_m(g))];

  /// A club the feed doesn't list (shouldn't happen): its id as its name.
  Club.unknown(this.id)
      : name = id,
        code = id.length >= 3 ? id.substring(0, 3).toUpperCase() : id.toUpperCase(),
        league = '',
        country = '',
        city = '',
        primary = const Color(0xFF14243D),
        onPrimary = const Color(0xFFFFFFFF),
        form = '',
        results = const [],
        fixtures = const [];

  final String id;
  final String name;
  final String code;
  final String league; // its home competition's code, 'URC'
  final String country;
  final String city;
  final Color primary, onPrimary;
  final String form; // last five, oldest first
  final List<ClubGame> results; // newest first, every competition
  final List<ClubGame> fixtures; // soonest first
}

class ClubsFeed {
  ClubsFeed({required this.asOf, required this.leagues, required this.clubs});

  factory ClubsFeed.fromJson(Map<String, dynamic> j) => ClubsFeed(
        asOf: _s(j['asOf']),
        leagues: [for (final l in _l(j['leagues'])) ClubLeague.fromJson(_m(l))],
        clubs: {for (final e in _m(j['clubs']).entries) e.key: Club.fromJson(e.key, _m(e.value))},
      );

  final String asOf;
  final List<ClubLeague> leagues;
  final Map<String, Club> clubs;

  Club club(String id) => clubs[id] ?? Club.unknown(id);

  ClubLeague? league(String code) {
    for (final l in leagues) {
      if (l.code == code || l.id == code) return l;
    }
    return null;
  }
}

const _clubWords = ['no', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];
String _cw(int n) => n >= 0 && n < _clubWords.length ? _clubWords[n] : '$n';

/// The one sentence to take away from a competition: who leads and by how much. The same wording as
/// `lgIdea` in pipeline/clubs_template.html (the website), so the two read alike. [name] turns a club id
/// into its name. Null for a cup, or when there is no table.
String? leagueIdea(ClubLeague l, String Function(String id) name) {
  if (l.isCup || l.table.length < 2) return null;
  if (!l.started) {
    return l.tableSeason.isNotEmpty && l.tableSeason != l.season && l.table.first.played > 0
        ? '${name(l.table.first.club)} finished top last season.'
        : null;
  }
  final a = l.table[0], b = l.table[1], gap = a.points - b.points;
  var t = gap > 0
      ? '${name(a.club)} top the table, $gap point${gap == 1 ? '' : 's'} clear of ${name(b.club)}'
      : '${name(a.club)} and ${name(b.club)} are level on ${a.points} points at the top';
  final perfect = [for (final r in l.table) if (r.played >= 3 && r.won == r.played) r];
  final only = perfect.length == 1 ? perfect.first : null;
  final hand = gap > 0 && b.played < a.played;
  if (hand) t += ', who have a game in hand';
  if (only != null && only.club == b.club && gap > 0) {
    return '$t${hand ? ' and are the' : ', the'} only side to have won all ${_cw(only.played)}.';
  }
  t += '.';
  if (only != null) {
    t += only.club == a.club
        ? ' ${name(a.club)} have won all ${_cw(only.played)}.'
        : ' ${name(only.club)} are the only side to have won all ${_cw(only.played)}.';
  } else if (perfect.isEmpty) {
    final unbeaten = [for (final r in l.table) if (r.played >= 3 && r.lost == 0) r];
    if (unbeaten.length == 1) t += ' ${name(unbeaten.first.club)} are the only side yet to lose.';
  }
  return t;
}

/// The one sentence to take away from a club page: where they stand and how their recent games went
/// ('Glasgow Warriors top the URC on 19 points from 5 matches, and have won 4 of their last 5.').
/// Like `clubIdea` on the website, which counts the last 10; the app's feed carries the last 5.
String? clubIdea(Club c, ClubLeague? home) {
  final pos = home == null || !home.started ? null : home.positionOf(c.id);
  final row = pos == null ? null : home!.table[pos - 1];
  final f = c.form, w = 'W'.allMatches(f).length;
  var t = '';
  if (row != null && row.played > 0) {
    t = pos == 1 ? '${c.name} top the ${home!.short}' : '${c.name} are ${ordinal(pos!)} in the ${home!.short}';
    t += ' on ${row.points} points from ${row.played} match${row.played == 1 ? '' : 'es'}';
  }
  if (f.length >= 3) {
    final form = w == f.length ? 'won their last ${f.length}' : 'won $w of their last ${f.length}';
    t = t.isEmpty ? '${c.name} have $form' : '$t, and have $form';
  }
  return t.isEmpty ? null : '$t.';
}
