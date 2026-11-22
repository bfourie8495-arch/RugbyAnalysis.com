// Live scores: https://rugbyanalysis.com/app/live.json, built by the website's Worker (worker/live.js) from
// ESPN while a Test is on. Unlike the other feeds it is never kept on the phone: a live score from an hour
// ago is worse than none. Pure Dart, so the tests can check it directly.

import 'feeds.dart' show Gender, parseKickOff;

/// Where a live game stands.
enum LiveState { pre, live, halfTime, fullTime }

/// One scoring play or card: [minute], [code] (T try, PT penalty try, C conversion, P penalty goal,
/// D drop goal, Y yellow card, R red card), [home] side or not, and the player ('T. Curry').
class LiveEvent {
  const LiveEvent({required this.minute, required this.code, required this.home, this.player = ''});

  final int minute;
  final String code;
  final bool home;
  final String player;

  static const _what = {
    'T': 'Try', 'PT': 'Penalty try', 'C': 'Conversion', 'P': 'Penalty goal', 'D': 'Drop goal', 'Y': 'Yellow card', 'R': 'Red card',
  };
  static const _points = {'T': 5, 'PT': 7, 'C': 2, 'P': 3, 'D': 3};

  /// 'Try', 'Penalty goal', 'Yellow card'.
  String get what => _what[code] ?? code;
  int get points => _points[code] ?? 0;
  bool get isCard => code == 'Y' || code == 'R';
  bool get isTry => code == 'T' || code == 'PT';
}

class LiveGame {
  const LiveGame({
    required this.gender,
    required this.home,
    required this.away,
    required this.state,
    this.kickOff,
    this.minute = '',
    this.homeScore = 0,
    this.awayScore = 0,
    this.events = const [],
  });

  factory LiveGame.fromJson(Map<String, dynamic> j) {
    final ev = j['ev'] is List ? j['ev'] as List : const [];
    return LiveGame(
      gender: j['g'] == 'w' ? Gender.women : Gender.men,
      home: '${j['h'] ?? ''}',
      away: '${j['a'] ?? ''}',
      kickOff: parseKickOff(j['ko']),
      state: switch (j['st']) { 'live' => LiveState.live, 'ht' => LiveState.halfTime, 'ft' => LiveState.fullTime, _ => LiveState.pre },
      minute: '${j['min'] ?? ''}',
      homeScore: j['hs'] is num ? (j['hs'] as num).toInt() : 0,
      awayScore: j['as'] is num ? (j['as'] as num).toInt() : 0,
      events: [
        for (final e in ev)
          if (e is List && e.length >= 3)
            LiveEvent(minute: e[0] is num ? (e[0] as num).toInt() : 0, code: '${e[1]}', home: e[2] == 'h', player: e.length > 3 ? '${e[3]}' : ''),
      ],
    );
  }

  final Gender gender;
  final String home;
  final String away;
  final DateTime? kickOff;
  final LiveState state;
  final String minute; // ESPN's clock while live: '54', '40+2'
  final int homeScore;
  final int awayScore;
  final List<LiveEvent> events; // oldest first

  /// Kicked off: there's a score worth showing.
  bool get started => state != LiveState.pre;

  /// The short label by the score: "54'", 'HT', 'FT' ('Live' before ESPN's clock starts).
  String get label => switch (state) {
        LiveState.pre => 'Soon',
        LiveState.halfTime => 'HT',
        LiveState.fullTime => 'FT',
        LiveState.live => minute.isEmpty ? 'Live' : "$minute'",
      };

  /// For screen readers: 'Live, 54th minute', 'Half-time', 'Full time'.
  String get spoken => switch (state) {
        LiveState.pre => 'Not started',
        LiveState.halfTime => 'Half-time',
        LiveState.fullTime => 'Full time',
        LiveState.live => minute.isEmpty ? 'Live' : 'Live, minute $minute',
      };

  int scoreOf(String team) => team == home ? homeScore : awayScore;
}

class LiveFeed {
  const LiveFeed({this.asOf, this.games = const []});

  factory LiveFeed.fromJson(Map<String, dynamic> j) => LiveFeed(
        asOf: DateTime.tryParse('${j['asOf'] ?? ''}'),
        games: [for (final g in j['games'] is List ? j['games'] as List : const []) if (g is Map) LiveGame.fromJson(g.cast<String, dynamic>())],
      );

  final DateTime? asOf;
  final List<LiveGame> games;

  /// The game between these two sides, whichever way round they're named.
  LiveGame? find(Gender g, String a, String b) {
    for (final x in games) {
      if (x.gender == g && ((x.home == a && x.away == b) || (x.home == b && x.away == a))) return x;
    }
    return null;
  }
}

/// Whether a kick-off is close enough to ask for live scores: 15 minutes before to 3 hours after
/// (the same window as worker/live.js).
bool inLiveWindow(DateTime? kickOff, DateTime now) {
  if (kickOff == null) return false;
  final mins = now.difference(kickOff).inMinutes;
  return mins >= -15 && mins <= 180;
}
