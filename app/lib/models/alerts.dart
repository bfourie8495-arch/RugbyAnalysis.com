// Which games are worth a heads-up, and what the heads-up says. Pure Dart, so
// it's tested directly. The server sends the real notifications with the same
// rules (functions/alerts.py); keep the two in step.

import 'feeds.dart';
import 'format.dart';

/// "Big games": Tests between two of the top 8 in the World Rugby rankings.
const bigGameTop = 8;

/// A followed team, stored as 'm|South Africa' or 'w|England'.
String followKey(Gender g, String team) => '${g.key}|$team';

/// The phone's alert settings. Saved on the phone and, with Firebase, at
/// users/{uid}, where the server reads them.
class AlertPrefs {
  const AlertPrefs({
    this.on = false,
    this.weekend = true,
    this.bigGames = true,
    this.bigGamesFor = const {Gender.men, Gender.women},
    this.kickoffMinutes = 60,
    this.fullTime = true,
    this.muted = const {},
    this.reminders = const {},
  });

  factory AlertPrefs.fromMap(Map<String, dynamic> m) => AlertPrefs(
        on: m['on'] == true,
        weekend: m['weekend'] != false,
        bigGames: m['bigGames'] != false,
        bigGamesFor: {for (final k in (m['bigGamesFor'] as List? ?? const ['m', 'w'])) Gender.fromKey('$k')},
        kickoffMinutes: (m['kickoffMinutes'] as num?)?.toInt() ?? 60,
        fullTime: m['fullTime'] != false,
        muted: {for (final k in (m['muted'] as List? ?? const [])) '$k'},
        reminders: {for (final k in (m['reminders'] as List? ?? const [])) '$k'},
      );

  final bool on; // master switch
  final bool weekend; // the weekend heads-up
  final bool bigGames;
  final Set<Gender> bigGamesFor;
  final int kickoffMinutes; // 0 = off, 15 or 60
  final bool fullTime;
  final Set<String> muted; // follow keys with alerts muted
  final Set<String> reminders; // one-off match reminders: 'm|2026-11-07|Wales|Japan'

  Map<String, Object?> toMap() => {
        'on': on,
        'weekend': weekend,
        'bigGames': bigGames,
        'bigGamesFor': [for (final g in bigGamesFor) g.key],
        'kickoffMinutes': kickoffMinutes,
        'fullTime': fullTime,
        'muted': muted.toList()..sort(),
        'reminders': reminders.toList()..sort(),
      };

  AlertPrefs copyWith({
    bool? on,
    bool? weekend,
    bool? bigGames,
    Set<Gender>? bigGamesFor,
    int? kickoffMinutes,
    bool? fullTime,
    Set<String>? muted,
    Set<String>? reminders,
  }) =>
      AlertPrefs(
        on: on ?? this.on,
        weekend: weekend ?? this.weekend,
        bigGames: bigGames ?? this.bigGames,
        bigGamesFor: bigGamesFor ?? this.bigGamesFor,
        kickoffMinutes: kickoffMinutes ?? this.kickoffMinutes,
        fullTime: fullTime ?? this.fullTime,
        muted: muted ?? this.muted,
        reminders: reminders ?? this.reminders,
      );
}

String reminderKey(Gender g, Fixture f) => '${g.key}|${f.date}|${f.home}|${f.away}';

enum WatchReason { yourTeam, bigGame, reminder }

class WatchItem {
  WatchItem(this.gender, this.fixture, this.reason, {this.team});
  final Gender gender;
  final Fixture fixture;
  final WatchReason reason;
  final String? team; // the followed team, for WatchReason.yourTeam
}

/// The Thursday that starts the "weekend" a date belongs to (Thursday to Wednesday).
DateTime weekendStart(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: (d.weekday - DateTime.thursday) % 7));
}

/// Every upcoming fixture worth a ping: a followed (and not muted) team, a big
/// game, or a one-off reminder. Soonest first.
List<WatchItem> worthWatching(MatchdayFeed feed, Set<String> follows, AlertPrefs prefs, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final todayYmd = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final out = <WatchItem>[];
  for (final g in Gender.values) {
    final side = feed.side(g);
    final top = {for (final r in side.ranked) if (r.position <= bigGameTop) r.team};
    for (final f in side.fixtures) {
      if (f.date.compareTo(todayYmd) < 0) continue;
      String? mine;
      for (final t in [f.home, f.away]) {
        final k = followKey(g, t);
        if (mine == null && follows.contains(k) && !prefs.muted.contains(k)) mine = t;
      }
      if (mine != null) {
        out.add(WatchItem(g, f, WatchReason.yourTeam, team: mine));
      } else if (prefs.bigGames && prefs.bigGamesFor.contains(g) && top.contains(f.home) && top.contains(f.away)) {
        out.add(WatchItem(g, f, WatchReason.bigGame));
      } else if (prefs.reminders.contains(reminderKey(g, f))) {
        out.add(WatchItem(g, f, WatchReason.reminder));
      }
    }
  }
  int when(WatchItem w) => (w.fixture.kickOff ?? DateTime.parse('${w.fixture.date}T12:00:00Z')).millisecondsSinceEpoch;
  out.sort((a, b) => when(a).compareTo(when(b)));
  return out;
}

/// The first weekend (Thursday to Wednesday) that has something worth watching.
List<WatchItem> nextWeekend(List<WatchItem> items) {
  if (items.isEmpty) return const [];
  DateTime start(WatchItem w) => weekendStart(DateTime.parse(w.fixture.date));
  final first = start(items.first);
  return [for (final w in items) if (start(w) == first) w];
}

/// The weekend heads-up's title and body.
({String title, String body}) headsUpText(List<WatchItem> weekend) {
  final n = weekend.length;
  final title = n == 1 ? '${weekend.first.fixture.home} v ${weekend.first.fixture.away} this weekend' : '$n games for you this weekend';
  String line(WatchItem w) {
    final k = w.fixture.kickOff?.toLocal();
    final when = k == null ? '${dateLabel(w.fixture.date).substring(0, 3)}, time TBC' : '${dayLabel(k).substring(0, 3)} ${clock(k)}';
    return '$when · ${w.fixture.home} v ${w.fixture.away}';
  }

  final lines = [for (final w in weekend.take(3)) line(w)];
  if (n > 3) lines.add('+${n - 3} more');
  return (title: title, body: lines.join('\n'));
}
