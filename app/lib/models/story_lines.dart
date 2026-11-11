import 'feeds.dart';

/// Section titles written from the data, so a reader who only reads the titles still gets the story
/// (the Storytelling with Data review, round two). Pure functions, pinned in test/story_lines_test.dart.

const _words = ['no', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];
String _word(int n) => n >= 0 && n < _words.length ? _words[n] : '$n';

/// 'Wales at 22%: the year's biggest upset'. [upsets] are biggest first.
String upsetsTitle(List<Result> upsets) {
  final u = upsets.isEmpty ? null : upsets.first;
  if (u == null || u.winner == null || u.winnerChance == null) return 'Upsets of the year';
  return '${u.winner} at ${u.winnerChance}%: the year’s biggest upset';
}

/// 'Bielle-Biarrey and Jordan lead with 11 tries'. [hot] are most tries first.
String scorersTitle(List<({String player, String team, int tries, int tests})> hot) {
  if (hot.isEmpty) return 'Who’s scoring';
  final top = hot.first.tries;
  final leaders = [for (final h in hot) if (h.tries == top) h.player];
  final t = top == 1 ? 'try' : 'tries';
  return switch (leaders.length) {
    1 => '${leaders[0]} leads with $top $t',
    2 => '${leaders[0]} and ${leaders[1]} lead with $top $t',
    _ => '${_word(leaders.length)[0].toUpperCase()}${_word(leaders.length).substring(1)} players share the lead on $top $t',
  };
}

/// How the average margin moved between the first and second half of the last [n] Tests.
/// [shift] is the change in points a game (positive = better).
String trendTitle(double shift) {
  final p = shift.abs().round();
  if (shift.abs() < 3) return 'Holding steady';
  return shift > 0 ? 'Up $p points a game' : 'Down $p points a game';
}

String trendSentence(double shift, int half) {
  if (shift.abs() < 3) return 'The average margin is about the same as $half Tests ago.';
  return shift > 0
      ? 'Winning by ${shift.round()} points a game more than in the $half Tests before.'
      : '${(-shift).round()} points a game worse than in the $half Tests before.';
}
