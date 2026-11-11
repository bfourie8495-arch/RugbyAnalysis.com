import 'clubs.dart';
import 'feeds.dart';
import 'format.dart';

/// Links from the app to the matching page on rugbyanalysis.com, and the text for sharing a match.
///
/// The website is one page that reads the part after `#` as which page to show (`#south-africa`,
/// `#h2h/france-v-south-africa`, `#women/...` for the women's side). So `?ref=` (who sent the visitor)
/// goes BEFORE the `#`: `https://rugbyanalysis.com/?ref=app#h2h/france-v-south-africa`. Put after the
/// `#`, it would become part of the page name and the site would fall back to Matchday.

const siteHome = 'https://rugbyanalysis.com';

/// A nation's id on the website. A copy of `slug` in `pipeline/build.py`: lower case, é and ç
/// turned into e and c, every run of other characters becomes one hyphen, none at either end.
/// Keep the two in step (test/site_links_test.dart pins the cases).
String siteSlug(String name) => name
    .toLowerCase()
    .replaceAll('é', 'e')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _url(Gender g, String page, String ref) => '$siteHome/?ref=$ref#${g == Gender.women ? 'women/' : ''}$page';

/// A nation's page: its full record.
String siteTeamUrl(Gender g, String team, {String ref = 'app'}) => _url(g, siteSlug(team), ref);

/// The head-to-head page for two nations, home side first (as the site's own links are).
String siteH2hUrl(Gender g, String home, String away, {String ref = 'app'}) =>
    _url(g, 'h2h/${siteSlug(home)}-v-${siteSlug(away)}', ref);

/// A competition's page on the club site: `https://rugbyanalysis.com/clubs?ref=app#urc`. The club site reads
/// its own `#`: the competition's id, then a club's id, with `women/` first for a women's competition.
String siteLeagueUrl(ClubLeague l, {String ref = 'app'}) =>
    '$siteHome/clubs?ref=$ref#${l.gender == Gender.women ? 'women/' : ''}${l.id}';

/// A club's page on the club site, within its home competition: `...clubs?ref=app#urc/glasgow`.
String siteClubUrl(ClubLeague home, String clubId, {String ref = 'app'}) => '${siteLeagueUrl(home, ref: ref)}/$clubId';

/// What the Share button sends. Text only.
/// - Before the game: the fixture, kick-off in the sender's time (with its zone, since the friend may be
///   somewhere else), the model's pick and a link to the head-to-head.
/// - Once the result is in: the score and the link, nothing else (no pick to gloat or wince over).
/// [zone] is the time-zone label for the kick-off; by default the phone's own ('GMT', 'SAST').
String shareText(Gender g, {Fixture? fixture, Result? result, String? zone}) {
  assert((fixture == null) != (result == null), 'Share a fixture or a result, not both');
  final w = g == Gender.women ? ' (women)' : '';
  if (result != null) {
    final r = result;
    return 'Full time$w: ${r.home} ${r.homeScore}–${r.awayScore} ${r.away}.\n'
        'Head to head: ${siteH2hUrl(g, r.home, r.away, ref: 'share')}';
  }
  final f = fixture!;
  final k = f.kickOff?.toLocal();
  final when = k == null ? dateLabel(f.date) : '${dayLabel(k)}, ${clock(k)} ${zone ?? k.timeZoneName}';
  final p = pickOf(f.home, f.away, f.pick);
  return '${f.home} v ${f.away}$w, $when.'
      '${p == null ? '' : ' The model picks ${p.team} (${p.pct}%).'}\n'
      '${siteH2hUrl(g, f.home, f.away, ref: 'share')}';
}
