import 'feeds.dart';
import 'format.dart';

/// "Where it's at" for a tournament, in a line or two: for someone who watches the big games but
/// doesn't follow a competition week to week (which round is next, how many are left, what's after).
///
/// The rounds come from the table and the fixture list: each team has played its row's P games and
/// has its remaining fixtures still to come, so the round count is the most any team plays.
String whereItsAt(Tournament t, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final next = t.fixtures.isEmpty ? null : t.fixtures.first;
  String when(Fixture f) => f.kickOff == null ? shortDate(f.date) : dayLabel(f.kickOff!.toLocal());

  if (t.status == TournamentStatus.done) {
    final winners = [for (final g in t.groups) if (g.rows.isNotEmpty) g.rows.first.team];
    if (t.isSeries || winners.isEmpty) return 'Finished.';
    return winners.length == 1 ? 'Finished: won by ${winners.first}.' : 'Finished: ${winners.join(' and ')} topped their groups.';
  }

  if (t.isSeries) {
    final played = t.results.length;
    final left = t.fixtures.length;
    if (next == null) return '$played Tests played. No more are scheduled yet.';
    return '$played Tests played, $left to come. Next: ${next.home} v ${next.away}, ${when(next)}.';
  }

  final rows = [for (final g in t.groups) ...g.rows];
  if (rows.isEmpty || rows.every((r) => r.played == 0)) {
    return next == null ? 'Not started yet.' : 'Starts ${when(next)} with ${next.home} v ${next.away}.';
  }
  final played = rows.map((r) => r.played).reduce((a, b) => a > b ? a : b);
  final total = rows
      .map((r) => r.played + t.fixtures.where((f) => f.involves(r.team)).length)
      .reduce((a, b) => a > b ? a : b);
  final finalsNote = t.finals.isNotEmpty ? ' Then finals.' : '';
  if (next == null || played >= total) {
    return t.finals.isNotEmpty ? 'The group stage is over: finals next.' : 'All $total rounds played.';
  }
  final soon = next.kickOff != null && next.kickOff!.toLocal().difference(today).inDays < 7;
  final round = 'Round ${played + 1}';
  return 'After round $played of $total. ${soon ? '$round is this week, starting ${when(next)}' : '$round starts ${when(next)}'}.$finalsNote';
}
