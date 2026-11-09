import 'dart:ui' show Color;

import 'feeds.dart' show Gender;

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
