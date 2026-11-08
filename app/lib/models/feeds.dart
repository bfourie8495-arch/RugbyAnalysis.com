// The three feeds the website publishes for the app, as Dart classes:
//   matchday.json     rankings, upcoming Tests with the model's pick, results, form
//   tournaments.json  tournament tables, each nation's tournaments, the World Cup
//   analysis.json     style of play, packs and key players (read in a later step)
// Parsing is plain Dart with no Flutter, so the tests can check it directly.
// `fromJson` constructors are like a Python classmethod that builds an object
// from a dict; the small helpers below turn loosely typed JSON into real types.

import 'dart:ui' show Color;

Map<String, dynamic> _map(Object? x) => x is Map ? x.cast<String, dynamic>() : const {};
List<dynamic> _list(Object? x) => x is List ? x : const [];
String _str(Object? x) => x is String ? x : '';
int _int(Object? x) => x is num ? x.toInt() : 0;
double _dbl(Object? x) => x is num ? x.toDouble() : 0;
double? _dblOrNull(Object? x) => x is num ? x.toDouble() : null;

/// A kick-off time from the feeds ('2026-11-07T14:10:00Z' or '2027-10-01T10:45Z').
DateTime? parseKickOff(Object? x) {
  if (x is! String || x.isEmpty) return null;
  final s = RegExp(r'T\d\d:\d\dZ$').hasMatch(x) ? x.replaceFirst('Z', ':00Z') : x;
  return DateTime.tryParse(s);
}

/// Men's or women's rugby. The feeds key them 'm' and 'w'.
enum Gender {
  men('m', 'Men'),
  women('w', 'Women');

  const Gender(this.key, this.label);
  final String key;
  final String label;

  static Gender fromKey(String k) => k == 'w' ? women : men;
}

/// A flag emoji from an ISO code: 'za' -> South Africa's flag. England,
/// Scotland and Wales ('gb-eng', 'gb-sct', 'gb-wls') use the special
/// sequences those flags need. Empty when there's no code.
String flagEmoji(String iso) {
  if (iso.isEmpty) return '';
  final code = iso.toLowerCase();
  if (code.startsWith('gb-')) {
    // A black flag, then the subdivision spelled in "tag" letters, then an end tag.
    final tags = 'gb${code.substring(3)}'.codeUnits.map((c) => 0xE0061 + (c - 0x61));
    return String.fromCharCodes([0x1F3F4, ...tags, 0xE007F]);
  }
  if (code.length != 2) return '';
  return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + (c - 0x61)));
}

Color _hex(String s, Color fallback) {
  final h = s.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  return v == null || h.length != 6 ? fallback : Color(0xFF000000 | v);
}

class Nation {
  const Nation({required this.name, required this.code, required this.iso, required this.primary, required this.onPrimary, this.nick = ''});

  factory Nation.fromJson(String name, Map<String, dynamic> j) => Nation(
        name: name,
        code: _str(j['code']),
        iso: _str(j['iso']),
        primary: _hex(_str(j['p']), const Color(0xFF2E4A7A)),
        onPrimary: _hex(_str(j['onp']), const Color(0xFFFFFFFF)),
        nick: _str(j['nick']),
      );

  /// A team the feed doesn't describe: a neutral colour and the first three letters.
  factory Nation.unknown(String name) => Nation(
        name: name,
        code: name.replaceAll(RegExp('[^A-Za-z]'), '').padRight(3).substring(0, 3).toUpperCase(),
        iso: '',
        primary: const Color(0xFF2E4A7A),
        onPrimary: const Color(0xFFFFFFFF),
      );

  final String name;
  final String code;
  final String iso;
  final Color primary;
  final Color onPrimary;
  final String nick;

  String get flag => flagEmoji(iso);
}

class Fixture {
  Fixture({required this.date, required this.home, required this.away, this.kickOff, this.comp = '', this.venue = '', this.pick, this.live = false});

  factory Fixture.fromJson(Map<String, dynamic> j, {String comp = ''}) => Fixture(
        date: _str(j['d']),
        kickOff: parseKickOff(j['ko']),
        home: _str(j['h']),
        away: _str(j['a']),
        comp: comp.isNotEmpty ? comp + (_str(j['r']).isNotEmpty ? ' · ${_str(j['r'])}' : '') : _str(j['c']),
        venue: _str(j['v']),
        pick: _dblOrNull(j['p']),
        live: j['live'] == 1 || j['live'] == true,
      );

  final String date; // yyyy-mm-dd

  /// Being played when the feed was built (it stays a fixture until its result is in).
  final bool live;
  final DateTime? kickOff; // UTC; null when the time isn't known yet
  final String home;
  final String away;
  final String comp;
  final String venue;

  /// The model's chance that the home side wins (0 to 1), when there is one.
  final double? pick;

  bool involves(String team) => home == team || away == team;
  String get key => '$date|$home|$away';
}

class Result {
  Result({required this.date, required this.home, required this.away, required this.homeScore, required this.awayScore, this.comp = '', this.detail});

  factory Result.fromJson(Map<String, dynamic> j) => Result(
        date: _str(j['d']),
        home: _str(j['h']),
        away: _str(j['a']),
        homeScore: _int(j['hs']),
        awayScore: _int(j['as']),
        comp: _str(j['c']),
        detail: MatchDetail.fromJson(j),
      );

  /// A result from a compact [date, home, away, home score, away score] list.
  static Result? fromRow(Object? x) =>
      x is List && x.length >= 5 ? Result(date: _str(x[0]), home: _str(x[1]), away: _str(x[2]), homeScore: _int(x[3]), awayScore: _int(x[4])) : null;

  final String date;
  final String home;
  final String away;
  final int homeScore;
  final int awayScore;
  final String comp;

  /// Tries, kicks, cards and so on, for the latest results (empty when the record has none).
  final MatchDetail? detail;

  bool involves(String team) => home == team || away == team;
  String get key => '$date|$home|$away';
  String? get winner => homeScore > awayScore ? home : awayScore > homeScore ? away : null;
  int scoreOf(String team) => team == home ? homeScore : awayScore;
}

/// One side's numbers in a finished Test. Null where the record doesn't say.
class SideDetail {
  SideDetail.fromJson(Map<String, dynamic> j, String k)
      : tries = _intOrNull(j['${k}t']),
        cons = _intOrNull(j['${k}c']),
        pens = _intOrNull(j['${k}p']),
        drops = _intOrNull(j['${k}dg']),
        yellow = _intOrNull(j['${k}y']),
        red = _intOrNull(j['${k}r']),
        scorers = _str(j['${k}sc']);

  final int? tries;
  final int? cons;
  final int? pens;
  final int? drops;
  final int? yellow;
  final int? red;
  final String scorers; // 'Kolbe (2); Arendse', or ''
}

int? _intOrNull(Object? x) => x is num ? x.toInt() : null;

/// What the record holds about a Test beyond the score.
class MatchDetail {
  MatchDetail._(this.home, this.away, this.referee, this.ground, this.city, this.crowd);

  /// Null when the feed has nothing beyond the score.
  static MatchDetail? fromJson(Map<String, dynamic> j) {
    const keys = ['ht', 'at', 'hy', 'ay', 'hsc', 'asc', 'ref', 'gr', 'att'];
    if (!keys.any(j.containsKey)) return null;
    return MatchDetail._(SideDetail.fromJson(j, 'h'), SideDetail.fromJson(j, 'a'), _str(j['ref']), _str(j['gr']), _str(j['city']), _intOrNull(j['att']));
  }

  final SideDetail home;
  final SideDetail away;
  final String referee;
  final String ground;
  final String city;
  final int? crowd;

  bool get hasScoring => home.tries != null && away.tries != null;
  bool get hasCards => home.yellow != null && away.yellow != null;
}

/// Every Test between two nations, from the matchday feed. [a] and [b] are in alphabetical order;
/// [forPair] turns it round so the first team is the one you ask for.
class HeadToHead {
  HeadToHead({required this.a, required this.b, required this.record, required this.last10, required this.first, required this.avg,
      required this.biggest, required this.meetings});

  factory HeadToHead.fromJson(Map<String, dynamic> j) => HeadToHead(
        a: _str(j['a']),
        b: _str(j['b']),
        record: [for (final x in _list(j['rec'])) _int(x)],
        last10: [for (final x in _list(j['last10'])) _int(x)],
        first: _str(j['first']),
        avg: [for (final x in _list(j['avg'])) _dbl(x)],
        biggest: {for (final e in _map(j['big']).entries) if (Result.fromRow(e.value) case final r?) e.key: r},
        meetings: [for (final m in _list(j['last'])) if (Result.fromRow(m) case final r?) r],
      );

  final String a;
  final String b;
  final List<int> record; // a's wins, draws, b's wins
  final List<int> last10; // the same, over the last ten meetings
  final String first; // year of the first meeting
  final List<double> avg; // a's and b's average score over the last ten
  final Map<String, Result> biggest; // each side's biggest win
  final List<Result> meetings; // newest first

  int get played => record.fold(0, (x, y) => x + y);

  /// The same head-to-head with [team] first.
  HeadToHead forPair(String team) => team == a || record.length < 3
      ? this
      : HeadToHead(a: b, b: a, record: record.reversed.toList(), last10: last10.reversed.toList(), first: first, avg: avg.reversed.toList(),
          biggest: biggest, meetings: meetings);
}

/// One side's results against a shared opponent.
typedef VsRecord = ({int won, int drawn, int lost, int pointsFor, int pointsAgainst, String lastDate, int lastFor, int lastAgainst});

VsRecord? _vs(Object? x) {
  if (x is! List || x.length < 6) return null;
  final last = _list(x[5]);
  return (
    won: _int(x[0]),
    drawn: _int(x[1]),
    lost: _int(x[2]),
    pointsFor: _int(x[3]),
    pointsAgainst: _int(x[4]),
    lastDate: last.isEmpty ? '' : _str(last[0]),
    lastFor: last.length > 1 ? _int(last[1]) : 0,
    lastAgainst: last.length > 2 ? _int(last[2]) : 0,
  );
}

/// How two nations have each done against the teams they've both played lately (not each other):
/// the "how good were their opponents, really?" view. [first]'s numbers come first.
class CommonOpponents {
  CommonOpponents({required this.since, required this.rows});

  factory CommonOpponents.fromJson(Map<String, dynamic> j) => CommonOpponents(
        since: _str(j['since']),
        rows: [
          for (final r in _list(j['opp']))
            if (r is List && r.length >= 3)
              if ((_vs(r[1]), _vs(r[2])) case (final a?, final b?)) (opponent: _str(r[0]), first: a, second: b)
        ],
      );

  final String since; // yyyy-mm-dd
  final List<({String opponent, VsRecord first, VsRecord second})> rows; // most-played first

  CommonOpponents swapped() =>
      CommonOpponents(since: since, rows: [for (final r in rows) (opponent: r.opponent, first: r.second, second: r.first)]);

  /// Totals over every shared opponent: won, drawn, lost, and the average winning margin a game.
  static ({int won, int drawn, int lost, double margin}) total(Iterable<VsRecord> xs) {
    var w = 0, d = 0, l = 0, f = 0, a = 0;
    for (final x in xs) {
      w += x.won;
      d += x.drawn;
      l += x.lost;
      f += x.pointsFor;
      a += x.pointsAgainst;
    }
    final p = w + d + l;
    return (won: w, drawn: d, lost: l, margin: p == 0 ? 0 : (f - a) / p);
  }
}

/// A nation's numbers: all-time and this year's record, the last ten Tests, its streak and latest results.
class TeamStats {
  TeamStats.fromJson(Map<String, dynamic> j)
      : allTime = [for (final x in _list(j['all'])) _int(x)],
        since = _str(j['since']),
        year = [for (final x in _list(j['year'])) _int(x)],
        last = [for (final x in _list(j['last'])) _int(x)],
        lastN = _int(j['n']),
        pointsFor = _dbl(j['pf']),
        pointsAgainst = _dbl(j['pa']),
        triesFor = _dblOrNull(j['tf']),
        triesAgainst = _dblOrNull(j['ta']),
        triesFrom = _int(j['tn']),
        streak = _str(j['streak']),
        kicking = _list(j['kick']).length == 2 ? (made: _int(_list(j['kick'])[0]), tried: _int(_list(j['kick'])[1])) : null,
        cards = _list(j['cards']).length == 3
            ? (yellow: _int(_list(j['cards'])[0]), red: _int(_list(j['cards'])[1]), games: _int(_list(j['cards'])[2]))
            : null,
        pointsFromTries = j['tryPts'] is num ? _int(j['tryPts']) : null,
        scorers = [for (final x in _list(j['scorers'])) if (x is List && x.length >= 2) (player: _str(x[0]), tries: _int(x[1]))],
        recent = [
          for (final r in _list(j['recent']))
            if (r is List && r.length >= 6)
              (date: _str(r[0]), opponent: _str(r[1]), score: _int(r[2]), against: _int(r[3]), where: _str(r[4]), comp: _str(r[5]))
        ];

  final List<int> allTime; // won, drawn, lost
  final String since;
  final List<int> year; // this calendar year
  final List<int> last; // the last [lastN] Tests
  final int lastN;
  final double pointsFor; // a game, over the last ten
  final double pointsAgainst;
  final double? triesFor; // a game, over [triesFrom] of the last ten (where tries are recorded)
  final double? triesAgainst;
  final int triesFrom;
  final String streak; // 'W3'

  // Over the last twelve months (or the last ten Tests, if fewer), where the record has them:
  final ({int made, int tried})? kicking; // conversions and penalty goals
  final ({int yellow, int red, int games})? cards;
  final int? pointsFromTries; // % of points from tries and their conversions
  final List<({String player, int tries})> scorers; // the top three

  double? get kickingRate => kicking == null || kicking!.tried == 0 ? null : 100 * kicking!.made / kicking!.tried;
  double? get cardsAGame => cards == null || cards!.games == 0 ? null : (cards!.yellow + cards!.red) / cards!.games;
  final List<({String date, String opponent, int score, int against, String where, String comp})> recent; // newest first

  static double winRate(List<int> wdl) {
    final p = wdl.fold(0, (a, b) => a + b);
    return p == 0 ? 0 : 100 * wdl[0] / p;
  }

  String get streakText {
    if (streak.length < 2) return '';
    final n = int.tryParse(streak.substring(1)) ?? 0;
    final word = switch (streak[0]) { 'W' => n == 1 ? 'win' : 'wins', 'L' => n == 1 ? 'defeat' : 'defeats', _ => n == 1 ? 'draw' : 'draws' };
    return n == 1 ? '${switch (streak[0]) { 'W' => 'Won', 'L' => 'Lost', _ => 'Drew' }} last time' : '$n $word in a row';
  }
}

class Ranked {
  Ranked(this.team, this.position, this.points);
  final String team;
  final int position;
  final double points;
}

/// One side (men's or women's) of the matchday feed.
class MatchdaySide {
  MatchdaySide({required this.ranked, required this.fixtures, required this.results, required this.form, this.h2h = const {}, this.stats = const {}, this.common = const {}});

  factory MatchdaySide.fromJson(Map<String, dynamic> j) => MatchdaySide(
        ranked: [for (final r in _list(j['ranked'])) if (r is List && r.length >= 3) Ranked(_str(r[0]), _int(r[1]), _dbl(r[2]))],
        fixtures: [for (final f in _list(j['fixtures'])) Fixture.fromJson(_map(f))],
        results: [for (final r in _list(j['results'])) Result.fromJson(_map(r))],
        form: _map(j['form']).map((k, v) => MapEntry(k, _str(v))),
        h2h: _map(j['h2h']).map((k, v) => MapEntry(k, HeadToHead.fromJson(_map(v)))),
        stats: _map(j['stats']).map((k, v) => MapEntry(k, TeamStats.fromJson(_map(v)))),
        common: _map(j['common']).map((k, v) => MapEntry(k, CommonOpponents.fromJson(_map(v)))),
      );

  final List<Ranked> ranked;
  final List<Fixture> fixtures; // soonest first
  final List<Result> results; // newest first
  final Map<String, String> form; // 'WWLDW', oldest to newest
  final Map<String, HeadToHead> h2h; // 'Italy|South Africa' (alphabetical)
  final Map<String, TeamStats> stats;
  final Map<String, CommonOpponents> common; // 'Italy|South Africa' (alphabetical)

  /// How [first] and [second] have each done against the teams they've both played, [first]'s numbers first.
  CommonOpponents? sharedOpponents(String first, String second) {
    final names = [first, second]..sort();
    final c = common['${names[0]}|${names[1]}'];
    return c == null || names[0] == first ? c : c.swapped();
  }

  /// [first] against [second], with [first]'s numbers first. Null if they've never met (or the feed is older).
  HeadToHead? meeting(String first, String second) {
    final names = [first, second]..sort();
    return h2h['${names[0]}|${names[1]}']?.forPair(first);
  }

  /// The full record of this Test, if it's among the latest results.
  Result? resultFor(Result r) {
    for (final x in results) {
      if (x.date == r.date && x.home == r.home && x.away == r.away) return x;
    }
    return null;
  }

  int? rankOf(String team) {
    for (final r in ranked) {
      if (r.team == team) return r.position;
    }
    return null;
  }
}

class MatchdayFeed {
  MatchdayFeed({required this.asOf, required this.nations, required this.men, required this.women});

  factory MatchdayFeed.fromJson(Map<String, dynamic> j) => MatchdayFeed(
        asOf: _str(j['asOf']),
        nations: _map(j['nations']).map((k, v) => MapEntry(k, Nation.fromJson(k, _map(v)))),
        men: MatchdaySide.fromJson(_map(j['m'])),
        women: MatchdaySide.fromJson(_map(j['w'])),
      );

  final String asOf;
  final Map<String, Nation> nations;
  final MatchdaySide men;
  final MatchdaySide women;

  MatchdaySide side(Gender g) => g == Gender.men ? men : women;
  Nation nation(String team) => nations[team] ?? Nation.unknown(team);
}

// ---------------------------------------------------------------- tournaments

class StandingRow {
  StandingRow.fromJson(Map<String, dynamic> j)
      : pos = _int(j['pos']),
        team = _str(j['t']),
        played = _int(j['p']),
        won = _int(j['w']),
        drawn = _int(j['d']),
        lost = _int(j['l']),
        diff = _int(j['pd']),
        pointsFor = _int(j['pf']),
        pointsAgainst = _int(j['pa']),
        bonus = _int(j['tb']) + _int(j['lb']),
        points = _int(j['pts']);

  final int pos;
  final String team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int diff;
  final int pointsFor;
  final int pointsAgainst;
  final int bonus;
  final int points;
}

class TableGroup {
  TableGroup(this.name, this.rows);
  final String name;
  final List<StandingRow> rows;
}

/// A team's record in a series with no league table (the WXV Global Series).
class SeriesRecord {
  SeriesRecord(this.team, this.played, this.won, this.drawn, this.lost, this.pointsFor, this.pointsAgainst);
  final String team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int pointsFor;
  final int pointsAgainst;
  int get diff => pointsFor - pointsAgainst;
}

/// An edition's numbers: points and tries a game, the biggest win, the highest-scoring Test,
/// tries by team and the top try scorers (where the record names them).
class CompStats {
  CompStats.fromJson(Map<String, dynamic> j)
      : games = _int(j['games']),
        avgPoints = _dbl(j['avgPts']),
        avgTries = _dblOrNull(j['avgTries']),
        biggest = Result.fromRow(j['big']),
        highest = Result.fromRow(j['high']),
        tries = _map(j['tries']).map((k, v) => MapEntry(k, _int(v))),
        scorers = [for (final s in _list(j['scorers'])) if (s is List && s.length >= 3) (player: _str(s[0]), team: _str(s[1]), tries: _int(s[2]))],
        scorersFrom = _int(j['scorersFrom']);

  final int games;
  final double avgPoints;
  final double? avgTries;
  final Result? biggest;
  final Result? highest;
  final Map<String, int> tries; // empty unless every game's tries are recorded
  final List<({String player, String team, int tries})> scorers;
  final int scorersFrom; // how many of the games name their try scorers
}

enum TournamentStatus { live, next, done }

class Tournament {
  Tournament.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        gender = Gender.fromKey(_str(j['g'])),
        name = _str(j['name']),
        season = _str(j['season']),
        status = switch (_str(j['status'])) { 'live' => TournamentStatus.live, 'next' => TournamentStatus.next, _ => TournamentStatus.done },
        about = _str(j['about']),
        finals = _str(j['finals']),
        isSeries = _str(j['fmt']) == 'series',
        checked = j['checked'] != false,
        groups = [
          for (final g in _list(j['groups'])) TableGroup(_str(_map(g)['name']), [for (final r in _list(_map(g)['rows'])) StandingRow.fromJson(_map(r))])
        ],
        records = [
          for (final e in _map(j['teams']).entries)
            SeriesRecord(e.key, _int(_map(e.value)['p']), _int(_map(e.value)['w']), _int(_map(e.value)['d']), _int(_map(e.value)['l']),
                _int(_map(e.value)['pf']), _int(_map(e.value)['pa']))
        ],
        fixtures = [for (final f in _list(j['fixtures'])) Fixture.fromJson(_map(f), comp: _str(j['name']))],
        results = [for (final r in _list(j['results'])) Result.fromJson(_map(r))],
        sim = j['sim'] is Map ? GroupSim.fromJson(_map(j['sim'])) : null,
        stats = j['stats'] is Map ? CompStats.fromJson(_map(j['stats'])) : null;

  final String id;
  final Gender gender;
  final String name;
  final String season;
  final TournamentStatus status;
  final String about;
  final String finals;
  final bool isSeries;
  final bool checked; // false when no published table could be checked against
  final List<TableGroup> groups;
  final List<SeriesRecord> records;
  final List<Fixture> fixtures;
  final List<Result> results; // oldest first
  final GroupSim? sim;
  final CompStats? stats;

  /// Every team's played, points for and against, from the tables or the series records.
  List<({String team, int played, int pointsFor, int pointsAgainst})> get scoring => isSeries
      ? [for (final r in records) (team: r.team, played: r.played, pointsFor: r.pointsFor, pointsAgainst: r.pointsAgainst)]
      : [for (final g in groups) for (final r in g.rows) (team: r.team, played: r.played, pointsFor: r.pointsFor, pointsAgainst: r.pointsAgainst)];

  String get title => '$name $season';
}

/// The Nations Championship simulation: final places, finals weekend, title chances.
class GroupSim {
  GroupSim.fromJson(Map<String, dynamic> j)
      : about = _str(j['about']),
        title = [for (final t in _list(j['title'])) if (t is List && t.length >= 2) (team: _str(t[0]), pct: _dbl(t[1]))],
        teams = _map(j['teams']).map((k, v) => MapEntry(k, GroupSimTeam.fromJson(_map(v)))),
        finals = [for (final f in _list(j['finals'])) FinalsMatch.fromJson(_map(f))];

  final String about;
  final List<({String team, double pct})> title;
  final Map<String, GroupSimTeam> teams;
  final List<FinalsMatch> finals;
}

class GroupSimTeam {
  GroupSimTeam.fromJson(Map<String, dynamic> j)
      : place = [for (final x in _list(j['place'])) _dbl(x)],
        title = _dbl(j['title']),
        finalWin = _dbl(j['finalWin']),
        opponents = [for (final o in _list(j['opps'])) if (o is List && o.length >= 2) (team: _str(o[0]), pct: _dbl(o[1]))];

  final List<double> place; // chance of finishing 1st..6th, in %
  final double title;
  final double finalWin;
  final List<({String team, double pct})> opponents;

  int get likeliestPlace {
    var best = 0;
    for (var i = 1; i < place.length; i++) {
      if (place[i] > place[best]) best = i;
    }
    return best + 1;
  }
}

class FinalsMatch {
  FinalsMatch.fromJson(Map<String, dynamic> j)
      : place = _int(j['k']),
        kickOff = parseKickOff(j['ko']),
        venue = _str(j['v']),
        pairs = [for (final p in _list(j['pairs'])) if (p is List && p.length >= 3) (a: _str(p[0]), b: _str(p[1]), pct: _dbl(p[2]))];

  final int place;
  final DateTime? kickOff;
  final String venue;
  final List<({String a, String b, double pct})> pairs;
}

/// Where a nation sits in one tournament (from the feed's per-team index).
class TeamEntry {
  TeamEntry.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        group = _int(j['grp']),
        pos = _int(j['pos']),
        of = _int(j['of']),
        points = _int(j['pts']),
        played = _int(j['p']),
        record = [for (final x in _list(j['rec'])) _int(x)];

  final String id;
  final int group;
  final int pos;
  final int of;
  final int points;
  final int played;
  final List<int> record; // won, drawn, lost, for a series
}

// ---------------------------------------------------------------- World Cup

class WorldCupMatch {
  WorldCupMatch.fromJson(Map<String, dynamic> j)
      : date = _str(j['d']),
        kickOff = parseKickOff(j['ko'])!,
        localTime = _str(j['local']),
        home = _str(j['h']),
        away = _str(j['a']),
        venue = _str(j['v']),
        city = _str(j['city']),
        pool = _str(j['pool']),
        id = _str(j['id']),
        round = _str(j['round']),
        homeScore = j['hs'] is num ? _int(j['hs']) : null,
        awayScore = j['as'] is num ? _int(j['as']) : null;

  final String date;
  final DateTime kickOff;
  final String localTime; // the time at the ground
  final String home; // a team, or a label like 'Winner Pool A' in the knockouts
  final String away;
  final String venue;
  final String city;
  final String pool; // pool games only
  final String id; // knockouts only: 'R16 1', 'QF 2', 'Final'
  final String round; // knockouts only
  final int? homeScore;
  final int? awayScore;

  bool involves(String team) => home == team || away == team;
}

class WorldCupStage {
  WorldCupStage.fromJson(Map<String, dynamic> j)
      : stage = _str(j['s']),
        label = _str(j['lbl']),
        reach = _dbl(j['reach']),
        win = _dbl(j['win']),
        opponents = [for (final o in _list(j['opps'])) if (o is List && o.length >= 2) (team: _str(o[0]), pct: _dbl(o[1]))];

  final String stage; // R16, QF, SF, Final
  final String label;
  final double reach; // % of this scenario's runs that get this far
  final double win; // % chance of winning this game once there
  final List<({String team, double pct})> opponents;
}

class WorldCupScenario {
  WorldCupScenario.fromJson(Map<String, dynamic> j)
      : key = _str(j['k']),
        label = _str(j['lbl']),
        chance = _dbl(j['p']),
        title = _dbl(j['title']),
        slot = _str(_map(j['slot'])['id']),
        slotShare = _dbl(_map(j['slot'])['share']),
        stages = [for (final s in _list(j['stages'])) WorldCupStage.fromJson(_map(s))];

  final String key; // '1', '2', '3' or 'out'
  final String label;
  final double chance;
  final double title;
  final String slot; // round-of-16 match, e.g. 'R16 4'
  final double slotShare; // how often that slot (third-placed teams can land in different ones)
  final List<WorldCupStage> stages;
}

class WorldCupTeamSim {
  WorldCupTeamSim.fromJson(Map<String, dynamic> j)
      : pool = _str(j['pool']),
        reach = _map(j['reach']).map((k, v) => MapEntry(k, _dbl(v))),
        win = _dbl(j['win']),
        scenarios = [for (final s in _list(j['scen'])) WorldCupScenario.fromJson(_map(s))];

  final String pool;
  final Map<String, double> reach; // R16, QF, SF, Final -> %
  final double win;
  final List<WorldCupScenario> scenarios;
}

class WorldCup {
  WorldCup.fromJson(Map<String, dynamic> j)
      : name = _str(j['name']),
        host = _str(j['host']),
        start = _str(j['start']),
        end = _str(j['end']),
        firstKickOff = parseKickOff(j['firstKo'])!,
        format = _str(j['format']),
        pools = {
          for (final p in _list(j['pools'])) _str(_map(p)['p']): [for (final r in _list(_map(p)['rows'])) StandingRow.fromJson(_map(r))]
        },
        matches = [for (final m in _list(j['matches'])) WorldCupMatch.fromJson(_map(m))],
        knockouts = [for (final m in _list(j['knockouts'])) WorldCupMatch.fromJson(_map(m))],
        simAbout = _str(_map(j['sim'])['about']),
        titleChances = [for (final t in _list(_map(j['sim'])['title'])) if (t is List && t.length >= 2) (team: _str(t[0]), pct: _dbl(t[1]))],
        teamSims = _map(_map(j['sim'])['teams']).map((k, v) => MapEntry(k, WorldCupTeamSim.fromJson(_map(v))));

  final String name;
  final String host;
  final String start;
  final String end;
  final DateTime firstKickOff;
  final String format;
  final Map<String, List<StandingRow>> pools; // 'A'..'F'
  final List<WorldCupMatch> matches; // pool games, in kick-off order
  final List<WorldCupMatch> knockouts;
  final String simAbout;
  final List<({String team, double pct})> titleChances;
  final Map<String, WorldCupTeamSim> teamSims;

  String? poolOf(String team) {
    for (final e in pools.entries) {
      if (e.value.any((r) => r.team == team)) return e.key;
    }
    return null;
  }

  WorldCupMatch? firstMatchOf(String team) {
    for (final m in matches) {
      if (m.involves(team)) return m;
    }
    return null;
  }

  WorldCupMatch? knockout(String id) {
    for (final k in knockouts) {
      if (k.id == id) return k;
    }
    return null;
  }

  bool get finished => DateTime.now().toUtc().isAfter(DateTime.parse('${end}T23:59:00Z'));
}

class WomensWorldCup {
  WomensWorldCup.fromJson(Map<String, dynamic> j)
      : name = _str(j['name']),
        host = _str(j['host']),
        teams = _int(j['teams']),
        note = _str(j['note']),
        qualified = [for (final q in _list(j['qualified'])) if (q is List && q.length >= 2) (team: _str(q[0]), how: _str(q[1]))];

  final String name;
  final String host;
  final int teams;
  final String note;
  final List<({String team, String how})> qualified;
}

class TournamentsFeed {
  TournamentsFeed.fromJson(Map<String, dynamic> j)
      : asOf = _str(j['asOf']),
        tournaments = [for (final c in _list(j['comps'])) Tournament.fromJson(_map(c))],
        _index = {
          for (final g in Gender.values)
            g: _map(_map(j['teams'])[g.key]).map((k, v) => MapEntry(k, [for (final e in _list(v)) TeamEntry.fromJson(_map(e))]))
        },
        worldCup = WorldCup.fromJson(_map(_map(j['rwc'])['m'])),
        womensWorldCup = WomensWorldCup.fromJson(_map(_map(j['rwc'])['w']));

  final String asOf;
  final List<Tournament> tournaments;
  final Map<Gender, Map<String, List<TeamEntry>>> _index;
  final WorldCup worldCup;
  final WomensWorldCup womensWorldCup;

  List<Tournament> forGender(Gender g) {
    const order = {TournamentStatus.live: 0, TournamentStatus.next: 1, TournamentStatus.done: 2};
    return tournaments.where((t) => t.gender == g).toList()..sort((a, b) => order[a.status]!.compareTo(order[b.status]!));
  }

  Tournament? byId(String id) {
    for (final t in tournaments) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<TeamEntry> entriesFor(Gender g, String team) => _index[g]?[team] ?? const [];
}
