# RugbyAnalysis app (Flutter)

The RugbyAnalysis app for Android (and the web), built the same way as Smack Bang:
Flutter, one controller shared through a scope, one screen per file, and Firebase
for accounts and alerts. It reads its data from the website's feeds, which the
daily pipeline rebuilds every morning:

| Feed | What's in it |
|---|---|
| `rugbyanalysis.com/app/matchday.json` | Rankings, upcoming Tests with the model's pick, results, form, nation colours and flags |
| `rugbyanalysis.com/app/tournaments.json` | Tournament tables, each nation's tournaments, World Cup 2027 with predictions, Nations Championship predictions |
| `rugbyanalysis.com/app/analysis.json` | Style of play, packs and key players (not used by the app yet) |

## What's in this first version

- **Matchday:** the World Cup strip, "This weekend" (your teams, big games and reminders), every upcoming Test with the model's pick and both teams' form, the latest results.
- **Tournaments:** live ones first; each opens its tables, the Nations Championship predictions (title chances, likely finals weekend, chance of each place), what's still to play and the results.
- **World Cup:** 2027 pools, predictions with each team's scenarios, the schedule in your time, the knockouts; the women's 2029 World Cup.
- **Team and match pages:** follow a team, its tournaments and World Cup path, a match preview with "Remind me before kick-off".
- **Me:** your teams (mute any of them) and alerts: weekend heads-up, big games, kick-off reminders, full-time scores, with a preview of your next heads-up.
- **Alerts** are sent by three scheduled Cloud Functions (`functions/main.py`): Thursday 18:00 heads-up, kick-off reminders every 15 minutes, full-time scores every 30 minutes. No pings between 22:00 and 07:00.

Not in yet: clubs, sevens, head-to-heads, the Learn section and the style-of-play analysis from the prototype.

## Run it on your computer (about 15 minutes)

You already have Flutter from Smack Bang. In PowerShell:

1. Get the code and go to this folder:
   ```powershell
   git clone https://github.com/bfourie8495-arch/RugbyAnalysis.com.git
   cd RugbyAnalysis.com
   git checkout claude/flutter-app
   cd app
   ```
2. Make the Android and web folders (this never touches `lib/`):
   ```powershell
   flutter create . --org com.rugbyanalysis --project-name rugby_analysis --platforms android,web
   ```
3. In `android/app/src/main/AndroidManifest.xml`, add these two lines just above `<application`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```
   (Debug builds can reach the internet without the first line; release builds can't.)
4. Run it:
   ```powershell
   flutter pub get
   flutter run
   ```
   Without Firebase it works fully, but keeps your teams and alerts on the phone and sends no alerts.

## Connect it to Firebase (same project as Smack Bang)

It uses project **middle-509820**, with its own Firestore database and its own
functions, so it never touches Smack Bang's data or functions.

1. Firebase console > Firestore > **Add database**, named `rugbydb`, location `europe-west2` (London), production mode.
2. In this folder: `flutterfire configure --project=middle-509820 --platforms=android,web`. It adds the Android app (`com.rugbyanalysis.rugby_analysis`), writes `android/app/google-services.json` and replaces `lib/firebase_options.dart`.
3. Deploy the rules and the alert functions, from this folder:
   ```powershell
   firebase deploy --only firestore:rugbydb
   firebase deploy --only functions:rugby
   ```
   `firebase.json` here names the functions codebase `rugby`, so this never deletes or changes Smack Bang's functions. Anonymous sign-in is already on for the project.
4. Run the app on your phone, follow a team, and turn on alerts. Your settings appear at `users/{your uid}` in `rugbydb`, and the phone's token at `devices/{your uid}`.

## Checks

GitHub Actions (`.github/workflows/app.yml`) runs `flutter analyze`, `flutter test`
and the Python alert tests on every change to this folder. Locally:

```powershell
flutter analyze
flutter test
cd functions; python -m pytest
```
