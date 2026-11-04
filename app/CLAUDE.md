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
- Kick-off times in the feeds are UTC; screens always show `toLocal()` times.
- Flags are emoji from each nation's ISO code (`flagEmoji` in `feeds.dart`; England, Scotland and Wales use tag sequences). Nations without a code show their three-letter code in their colour (`TeamBadge`).

## Structure
- State: one `AppController` (ChangeNotifier) shared through `AppScope` (InheritedNotifier). `AppScope.of(context)` in `build`, `AppScope.read(context)` in handlers.
- One screen per file in `lib/screens/`; shared widgets in `lib/widgets/common.dart`, match tiles in `match_tiles.dart`, tables in `standings.dart`.
- Colours only from `RaColors` in `lib/theme.dart`. Gold is for highlights and numbers, never body text on light backgrounds.
- Tabs: Matchday, Tournaments, World Cup, Me (`home_shell.dart`, an IndexedStack, so all four are built at once: widget tests scope their finders to a screen).

## Firebase
- Project `middle-509820` (Smack Bang's). Firestore database **`rugbydb`**, set in `lib/services/backend.dart` and `firebase.json`. `lib/firebase_options.dart` is a placeholder until `flutterfire configure` runs on Brendon's machine; until then `Backend.connect()` returns null and everything stays on the phone.
- `users/{uid}`: `follows` ('m|South Africa'), `alerts` (`AlertPrefs.toMap`), `utcOffsetMinutes` (re-saved at each launch so the server writes times in the user's clock). `devices/{uid}`: FCM token. Rules in `firestore.rules`.
- Functions codebase **`rugby`** (`functions/`, Python 3.13): `weekend_heads_up` (Thu 18:00 UK), `kickoff_reminders` (every 15 min; the message gives the kick-off time), `full_time_scores` (every 30 min, results from the feed, deduplicated in `sent/results`). Pure rules in `functions/alerts.py`, mirrored in `lib/models/alerts.dart`: big game = both teams in the top 8; a followed team beats a big game; muted teams don't count; no pings 22:00 to 07:00 in the user's time. Keep the two copies in step.
- Deploy from `app/`: `firebase deploy --only firestore:rugbydb`, `firebase deploy --only functions:rugby`. Never deploy functions without the codebase filter.
