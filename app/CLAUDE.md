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

## Links to the website and sharing
- `lib/models/site_links.dart` (pure, tested in `test/site_links_test.dart`): `siteSlug` is a copy of `slug` in `pipeline/build.py` (lower case, é->e, ç->c, other runs -> one hyphen); change both together. `siteTeamUrl` / `siteH2hUrl` build `https://rugbyanalysis.com/?ref=app#south-africa` and `...#h2h/france-v-south-africa`, `#women/...` for women. **`?ref=` goes before the `#`**: the site reads everything after `#` as the page name, so a `?ref` there sends the visitor to Matchday.
- `WebsiteButton` (`common.dart`): "Full head to head on the website" (match screen, under the head-to-head) and "Full record on the website" (team screen, under the header), `ref=app`.
- Club site: `siteLeagueUrl` / `siteClubUrl` build `https://rugbyanalysis.com/clubs?ref=app#urc/glasgow` (`women/` first for a women's competition; the club page reads its own `#`). "Full club page on the website" (club screen, under the header) and "Full URC page on the website" (competition view, under the table). A test checks every competition id in the app exists as `LG("id"` in `pipeline/clubs_template.html`.
- Share (match screen top bar, `share_plus`) opens `showShareSheet` (`lib/widgets/share_card.dart`): a preview of `PickShareCard` (the pick, or after the game the score, in the post style: cream `RaColors.paper`, navy ink, gold = pick, grey = other side, home on the left, 4:5) with "Share picture" (the card drawn 1080 wide by `cardPng`, plus the text) and "Share as text". The words come from `shareCardText` (`lib/models/share_card.dart`) and the text from `shareText`, `ref=share`. Before the game: fixture, kick-off in the sender's time with its zone, the model's pick. Once the result is in: the score only. Kept apart from "Watch with friends", which invites people into a chat room.
- The test 'every nation playing in the feed has a page on the site' reads `../pipeline/others.json`. A few nations in `nations` (e.g. 'Bosnia & Herzegovina', "Cote D'Ivoire") have no site page; a link for them lands on the site's Matchday.

## Story lines (Storytelling with Data, round two)
- Titles and opening lines are written from the data, so a reader who only reads titles gets the story. Pure functions, pinned in `test/story_lines_test.dart`: `upsetsTitle`, `scorersTitle`, `trendTitle`/`trendSentence` (`lib/models/story_lines.dart`), `leagueIdea`/`clubIdea` (`lib/models/clubs.dart`, the same wording as `lgIdea`/`clubIdea` in `pipeline/clubs_template.html`; the app counts the last 5 games, the site the last 10), `streakTile` (`stats.dart`).
- Gold is rationed: one number per card (team: Last 10; season: v top-10; club form card: league points; a club table: the highlighted club's position). Club names are bold white, not gold. Form chips: W a cream fill, D a dark fill, L an outline, never gold. An upset result says "UPSET WIN"/"UPSET LOSS" in its gold box.
- See `design/README.md` for the house rules.

## Structure
- State: one `AppController` (ChangeNotifier) shared through `AppScope` (InheritedNotifier). `AppScope.of(context)` in `build`, `AppScope.read(context)` in handlers.
- One screen per file in `lib/screens/`; shared widgets in `lib/widgets/common.dart`, match tiles in `match_tiles.dart`, tables in `standings.dart`.
- Colours only from `RaColors` in `lib/theme.dart`. Gold is for highlights and numbers, never body text on light backgrounds.
- Tabs: Matchday, Tournaments, Clubs, Chat, Me (`home_shell.dart`, an IndexedStack, so all five are built at once: widget tests scope their finders to a screen). The current tab is `AppController.tab` (`AppTab`). The World Cup opens from the top of Tournaments and Matchday's strip.

## Clubs
- `pipeline/build_app_clubs.py` makes `site/app/clubs.json` from the website's `clubs_data.json` (names, colours and "how it works" from `clubs_template.html`): the ten competitions (URC, PREM, PWR, T14, SR, CC, NPC, JL1, ECC, EPC) with table (last season's until the new one has games), next 16 fixtures and last 16 results; each club's form and last/next 6 games. Kick-offs become UTC. Models in `lib/models/clubs.dart`; `test/data/clubs.json` is a copy.
- Loaded separately from the other feeds (`AppController._loadClubs`), so a problem with it never hides the Tests.
- Club follows are `AppController.clubFollows` (club ids), kept apart from `follows` (nations, which the server's alerts read and `follows.first` is "your team"), saved as `clubs` on `users/{uid}`. No club alerts yet.
- Screens: `ClubsScreen` (your clubs, competition chips, `LeagueView`), `ClubScreen`; widgets in `club_tiles.dart` (`ClubBadge`: the club's code in its colours, `ClubGameTile`, `ClubTable` with the play-off line). Matchday shows your clubs' next games within eight days.

## Chat
- Friends only: private rooms joined by invite. A room is `rooms/{code}` in rugbydb; its id is the invite code (12 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, `newRoomCode`). Fields: name, ownerUid, members, names {uid: chat name}, muted, match (pinned `PinnedMatch`: k 'm'/'w'/'c', d, h, a, ko, c), lastAt/lastText/lastName/lastUid, createdAt, deleteAt (90 days after the last message). Messages `rooms/{code}/messages/{id}`: uid, name, text (≤ 500), at, deleteAt (+30 days). `reports/{id}`: create only.
- Rules (`firestore.rules`): anyone signed in can get one room (to join); list only rooms you're in; joining adds only yourself (max 50); members change the name, pinned match, last-message fields, their own name/mute, or leave; the owner deletes. Messages: members read and post as themselves, no edits, delete your own (the owner any).
- `lib/services/chat_service.dart`: `ChatService` with `FirestoreChat` (the only other file that talks to Firebase besides `backend.dart`; `Backend.chat`) and `MemoryChat` for tests and screenshots (`AppController(chat: ...)`). Without a backend, `chatAvailable` is false and the tab says so.
- Your chat name is `myName` (`users/{uid}.name` and prefs). Hiding someone (`blocked`) and what you've read (`chatSeen`) stay on the phone. Reporting writes `reports/` and hides the sender.
- Screens: `ChatScreen` (rooms, New room, Join with a code, name dialog, `JoinRoomScreen`), `RoomScreen`; widgets in `chat_widgets.dart` (`PinnedMatchCard` shows the score once it's in, `showInvite`, `pickMatch`, `watchWithFriends` from the match screen).
- Invites: `rugbyanalysis.com/join/CODE` is served by `worker/index.js` (`joinPage`): "Open in the app" is an `intent://` link to `rugbyanalysis://app/join/CODE` (AndroidManifest intent-filter), falling back to Google Play. Flutter turns it into the route `/join/CODE`; `main.dart` `onGenerateRoute`/`onGenerateInitialRoutes` open `JoinRoomScreen`.
- Alerts: `on_chat_message` in `functions/main.py` (Firestore trigger on rugbydb) alerts members except the sender and those who muted the room, if their alerts are on; one Android notification tag per room. Rules in `functions/chat.py`. A tap (`data.room`) opens the room.
- TTL policies needed in rugbydb: collection group `messages` field `deleteAt`, and `rooms` field `deleteAt`. The privacy policy promises the 30 days.

## Firebase
- Project `middle-509820` (Smack Bang's). Firestore database **`rugbydb`**, set in `lib/services/backend.dart` and `firebase.json`. `setup.ps1` (run once on Brendon's PC) registers the Android app `com.rugbyanalysis.app` and the web app "RugbyAnalysis (web)", writes `lib/firebase_options.dart` and `android/app/google-services.json`, creates the database and deploys. Before that, `firebase_options.dart` is a placeholder, `Backend.connect()` returns null and everything stays on the phone.
- `users/{uid}`: `follows` ('m|South Africa'), `alerts` (`AlertPrefs.toMap`), `utcOffsetMinutes` (re-saved at each launch so the server writes times in the user's clock). `devices/{uid}`: FCM token. Rules in `firestore.rules`.
- Functions codebase **`rugby`** (`functions/`, Python 3.13): `weekend_heads_up` (Thu 18:00 UK), `kickoff_reminders` (every 15 min; the message gives the kick-off time), `full_time_scores` (every 30 min, results from the feed, deduplicated in `sent/results`). Pure rules in `functions/alerts.py`, mirrored in `lib/models/alerts.dart`: big game = both teams in the top 8; a followed team beats a big game; muted teams don't count; no pings 22:00 to 07:00 in the user's time. Keep the two copies in step.
- Deploy from `app/`: `firebase deploy --only firestore --project middle-509820` (only rugbydb is in this firebase.json), `firebase deploy --only functions:rugby --project middle-509820` (needs `functions/venv`, which setup.ps1 makes). Never deploy functions without the codebase filter.
- `android/` and `web/` are committed (adapted from Smack Bang's; the Android package is `com.rugbyanalysis.app`, permanent once on Play). Icons come from `tool/make_icons.py`, drawn from `site/logo` (gold ball on navy).

## Google Play
- Package `com.rugbyanalysis.app`, personal developer account (closed test with 12+ testers for 14 days before production). Listing answers in `store/play-listing.md`; keep them true when the app changes what it collects.
- Signing: `make-upload-key.ps1` makes the upload key and the GitHub secrets `UPLOAD_KEYSTORE_BASE64`, `UPLOAD_KEYSTORE_PASSWORD`, `UPLOAD_KEY_ALIAS`, `UPLOAD_KEY_PASSWORD`; `.github/workflows/app-apk.yml` signs the APK (release `app-latest`) and the AAB (run artifact) with it, build number 100 + run number.
- Privacy: `site/privacy.html` and `site/delete-data.html`. "Delete my data" (Me) calls `AppController.deleteMyData` -> `ChatService.forgetMe` (leaves rooms, deletes your messages and the rooms you own) then `Backend.deleteEverything` (devices, users, the anonymous sign-in). `deleteAt` (a year ahead, renewed at each launch, token too via `Notifications.refresh`) needs TTL policies on users.deleteAt and devices.deleteAt in rugbydb.
- Store graphics: `tool/make_icons.py` (icon, feature graphic); screenshots: `tool/store_screenshots_test.dart`, rendered and committed by `.github/workflows/app-store-screenshots.yml`.
