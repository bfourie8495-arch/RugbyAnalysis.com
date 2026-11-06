// Small formatting helpers shared by the screens. Times are shown in the
// phone's own time zone (DateTime.toLocal), in UK-style day and month.

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 'Sat 7 Nov'
String dayLabel(DateTime t) => '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';

/// '14:10'
String clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// A date string from the feeds ('2026-11-07') as 'Sat 7 Nov'.
String dateLabel(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : dayLabel(d);
}

/// '7 Nov 26'
String shortDate(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : '${d.day} ${_months[d.month - 1]} ${(d.year % 100).toString().padLeft(2, '0')}';
}

/// A chance in % as shown in the app: '<1%', '28%', '>99%'.
String pct(double x) {
  if (x <= 0) return '0%';
  if (x < 1) return '<1%';
  if (x >= 99.5 && x < 100) return '>99%';
  return '${x.round()}%';
}

/// 1 -> '1st', 2 -> '2nd', 11 -> '11th'
String ordinal(int n) {
  final v = n % 100;
  if (v >= 11 && v <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

/// '+12', '-3', '0'
String signed(int n) => n > 0 ? '+$n' : '$n';

/// The model's pick for a fixture: ('Ireland', 77) for a home chance of 0.77.
({String team, int pct})? pickOf(String home, String away, double? homeChance) {
  if (homeChance == null) return null;
  return homeChance >= 0.5 ? (team: home, pct: (homeChance * 100).round()) : (team: away, pct: ((1 - homeChance) * 100).round());
}

/// Whole days from today to [day], counted in calendar days on this phone.
int daysUntil(DateTime day, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final d = day.toLocal();
  // UTC midnights, so a clock change between the two dates can't lose an hour and drop a day.
  return DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
}
