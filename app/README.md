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

## Set it up on your computer (one script)

You already have Flutter, Python and the Firebase CLI from Smack Bang. In PowerShell:

```powershell
cd ~
git clone -b claude/flutter-app https://github.com/bfourie8495-arch/RugbyAnalysis.com.git
cd RugbyAnalysis.com\app
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

`setup.ps1` connects the app to Smack Bang's Firebase project (**middle-509820**) without
touching any of Smack Bang's data, apps or functions. It's safe to run again; each step
checks what's already done.

1. Signs you in to Firebase if you're signed out.
2. Registers two apps in the project: Android `com.rugbyanalysis.app` and "RugbyAnalysis (web)".
   It writes `android/app/google-services.json` and `lib/firebase_options.dart`.
3. Creates the Firestore database `rugbydb` in `europe-west2` (London) and deploys its rules.
4. Deploys the alert functions as their own codebase, `rugby`.

Then plug in your phone and run `flutter run`.

The `android/` and `web/` folders are already in the repo, so there's no `flutter create`
step. The app icons are drawn from the website's logo by `tool/make_icons.py`.
Android builds need the Firebase file the script writes. The web version
(`flutter run -d chrome`) runs without it, keeping your teams and alerts in the browser.

To deploy again after a change, run these from this folder (always keep `:rugby` on functions):

```powershell
firebase deploy --only firestore --project middle-509820
firebase deploy --only functions:rugby --project middle-509820
```

## Checks

GitHub Actions (`.github/workflows/app.yml`) runs `flutter analyze`, `flutter test`
and the Python alert tests on every change to this folder. Locally:

```powershell
flutter analyze
flutter test
cd functions; python -m pytest
```
