# RugbyAnalysis app: notes for Claude Code

## What this is
The RugbyAnalysis Flutter app (Android first, web too), in `app/` of the RugbyAnalysis.com repo. Built the same way as Brendon's Smack Bang app (github.com/bfourie8495-arch/halfway_app): same structure, same Firebase project, its own database and functions. The design follows the clickable prototype on claude.ai (canvas "Rugby Analysis App") and the website: navy and gold, Poppins and Figtree.

The owner is Brendon. He knows Python and SQL well and is newer to Dart and Flutter. Explain Dart and Flutter concepts briefly when you introduce them, relating them to Python where helpful. Plain UK English in the app and in explanations.

## Commands
```
flutter pub get
flutter analyze
flutter test
cd functions && python -m pytest
```
Run all of them after every change; fix every error and warning. GitHub Actions (`.github/workflows/app.yml`) runs them on each push and shows problems as annotations.

## Data
- Everything comes from three feeds the pipeline builds daily (`pipeline/build_matchday.py`, `build_tournaments.py`, `build_analysis.py` in the repo root), served at `https://rugbyanalysis.com/app/*.json`. Change a feed's shape in the pipeline and in `lib/models/feeds.dart` together, and refresh the copies in `test/data/` (they're real feed files, so the tests check the app reads what the website publishes).
- `lib/services/feed_service.dart`: `WebFeedSource` downloads a feed and keeps the last good copy in shared_preferences, so the app opens offline. Tests use a `FeedSource` that reads `test/data/`.
- Kick-off times in the feeds are UTC; screens always show `toLocal()` times. `KickOffBlock` (`match_tiles.dart`) shows Today/Tomorrow/day, the time and `kickOffNote` (countdown, Live, Result soon). A Test being played stays in the fixtures (`live`) until its result is in.
- Results arrive fast: `.github/workflows/results-watch.yml` checks every 15 minutes (`pipeline/results_due.py`) and starts the data refresh when a kick-off was 100+ minutes ago and its fixture is still listed (up to 8 hours, at most every 25 minutes).
- Stats (from the results CSVs, in the same feeds): `matchday.json` has per side `h2h` ('A|B' in alphabetical order: record, last ten, biggest wins, latest meetings; `MatchdaySide.meeting` turns it round), `stats` per nation (all-time, this year, last ten averages, streak, latest results) and extra keys on the latest `results` (tries, kicks, cards, try scorers, referee, ground, crowd: `MatchDetail`). Tries count only where the record is believable (`tries_of` in `build_matchday.py`). Each tournament in `tournaments.json` has `stats` (`CompStats`: points and tries a game, biggest win, highest score, tries by team, top try scorers) and pf/pa per table row. `common` ('A|B') holds each side's record against the teams both have played in the last three years (`CommonOpponents`, "Against the same teams"), and `stats` also has goal-kicking, cards, points from tries and top try scorers over the last 12 months. Shown by `lib/widgets/stats.dart` on the match (fixtures and results: `MatchScreen.result`), team and tournament screens.
- Talking points (`pipeline/insights.py`, `lib/widgets/insights.dart`, `InsightsScreen`): pre-match chances for every Test come from a replay of World Rugby's ranking system over the whole record (`replay`), giving each result's `pw` (winner's chance, an upset under 40%), the year's `upsets`, and each team's `season` (last 12 months with its chance beforehand). Also `hot` try scorers, `trend` (last 20 scores), `close` games, and both sides' records at the ground (`gv`, grounds matched across sponsor names by `ground_key`) and with the referee (`rv`). Title-race `moves` in tournaments.json come from `pipeline/sim_history.json` (the simulation's title chances kept against games played; committed by the refresh).
- The in-app logo is `BrandMark` (`common.dart`), painted from the same numbers as `site/logo/icon.svg`; the launcher and store icons come from `tool/make_icons.py`.
- Flags are emoji from each nation's ISO code (`flagEmoji` in `feeds.dart`; England, Scotland and Wales use tag sequences). Nations without a code show their three-letter code in their colour (`TeamBadge`).

## Structure
- State: one `AppController` (ChangeNotifier) shared through `AppScope` (InheritedNotifier). `AppScope.of(context)` in `build`, `AppScope.read(context)` in handlers.
- One screen per file in `lib/screens/`; shared widgets in `lib/widgets/common.dart`, match tiles in `match_tiles.dart`, tables in `standings.dart`.
- Colours only from `RaColors` in `lib/theme.dart`. Gold is for highlights and numbers, never body text on light backgrounds.
- Tabs: Matchday, Tournaments, World Cup, Me (`home_shell.dart`, an IndexedStack, so all four are built at once: widget tests scope their finders to a screen).

## Firebase
- Project `middle-509820` (Smack Bang's). Firestore database **`rugbydb`**, set in `lib/services/backend.dart` and `firebase.json`. `setup.ps1` (run once on Brendon's PC) registers the Android app `com.rugbyanalysis.app` and the web app "RugbyAnalysis (web)", writes `lib/firebase_options.dart` and `android/app/google-services.json`, creates the database and deploys. Before that, `firebase_options.dart` is a placeholder, `Backend.connect()` returns null and everything stays on the phone.
- `users/{uid}`: `follows` ('m|South Africa'), `alerts` (`AlertPrefs.toMap`), `utcOffsetMinutes` (re-saved at each launch so the server writes times in the user's clock). `devices/{uid}`: FCM token. Rules in `firestore.rules`.
- Functions codebase **`rugby`** (`functions/`, Python 3.13): `weekend_heads_up` (Thu 18:00 UK), `kickoff_reminders` (every 15 min; the message gives the kick-off time), `full_time_scores` (every 30 min, results from the feed, deduplicated in `sent/results`). Pure rules in `functions/alerts.py`, mirrored in `lib/models/alerts.dart`: big game = both teams in the top 8; a followed team beats a big game; muted teams don't count; no pings 22:00 to 07:00 in the user's time. Keep the two copies in step.
- Deploy from `app/`: `firebase deploy --only firestore --project middle-509820` (only rugbydb is in this firebase.json), `firebase deploy --only functions:rugby --project middle-509820` (needs `functions/venv`, which setup.ps1 makes). Never deploy functions without the codebase filter.
- `android/` and `web/` are committed (adapted from Smack Bang's; the Android package is `com.rugbyanalysis.app`, permanent once on Play). Icons come from `tool/make_icons.py`, drawn from `site/logo` (gold ball on navy).

## Google Play
- Package `com.rugbyanalysis.app`, personal developer account (closed test with 12+ testers for 14 days before production). Listing answers in `store/play-listing.md`; keep them true when the app changes what it collects.
- Signing: `make-upload-key.ps1` makes the upload key and the GitHub secrets `UPLOAD_KEYSTORE_BASE64`, `UPLOAD_KEYSTORE_PASSWORD`, `UPLOAD_KEY_ALIAS`, `UPLOAD_KEY_PASSWORD`; `.github/workflows/app-apk.yml` signs the APK (release `app-latest`) and the AAB (run artifact) with it, build number 100 + run number.
- Privacy: `site/privacy.html` and `site/delete-data.html`. "Delete my data" (Me) calls `AppController.deleteMyData` -> `Backend.deleteEverything` (devices, users, the anonymous sign-in). `deleteAt` (a year ahead, renewed at each launch, token too via `Notifications.refresh`) needs TTL policies on users.deleteAt and devices.deleteAt in rugbydb.
- Store graphics: `tool/make_icons.py` (icon, feature graphic); screenshots: `tool/store_screenshots_test.dart`, rendered and committed by `.github/workflows/app-store-screenshots.yml`.
