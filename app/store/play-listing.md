# RugbyAnalysis on Google Play: what to paste where

Everything Play Console asks for, ready to copy. Images are in this folder:
`play-icon-512.png` (app icon) and `feature-graphic-1024x500.png`, both made by `tool/make_icons.py`,
and the phone screenshots in `screenshots/` (1080 x 1920), made on GitHub by
`tool/store_screenshots_test.dart` (workflow "App store screenshots").

## Create the app

- **App name:** `RugbyAnalysis: rugby picks` (26/30)
- **Default language:** English (United Kingdom), en-GB
- **App or game:** App. **Free or paid:** Free.
- **Package name:** `com.rugbyanalysis.app` (set by the first bundle uploaded; can never change)

## Main store listing

**Short description** (80/80)

```
Every rugby Test with the model's pick, tournament tables and World Cup chances.
```

**Full description** (1710/4000)

```
International rugby, explained by the numbers.

RugbyAnalysis follows every men's and women's Test: when they're on, who's likely to win and why, and where every team stands. It's built on the same model as rugbyanalysis.com, which updates daily.

Matchday
• Every upcoming Test with the model's pick and win chance, and both teams' recent form.
• Kick-off times in your own time zone.
• The latest results, and the world rankings.

Tournaments
• Tables for the Nations Championship, Six Nations, Rugby Championship, Pacific Four, WXV and more.
• Nations Championship predictions: each team's title chances, the likely finals weekend at Twickenham, and the chance of every finishing place.

Rugby World Cup 2027
• A countdown to Australia 2027, the pools and the full schedule in your time.
• Predictions from 20,000 simulated tournaments: who wins it, and how far each team is likely to go.
• Scenarios for your team: top their pool, finish second or sneak through third, and who they would likely meet next.
• The women's Rugby World Cup 2029, too.

A heads-up when it matters
Don't follow rugby closely enough to know when the games are on? Follow your teams and RugbyAnalysis tells you:
• On Thursday evening: this weekend's games for you.
• Big games between two top-eight teams, even if you don't follow either.
• A reminder an hour or 15 minutes before kick-off.
• The full-time score.
No pings between 10pm and 7am.

Private by design
No account, no ads and no tracking. The app keeps only the teams you follow and your alert settings, under an anonymous ID, and you can delete them at any time in the app.

RugbyAnalysis is independent and not affiliated with World Rugby, any union or any tournament.
```

**App category:** Sports. **Tags:** Sports news, Rugby (or the closest Play offers).

**Contact email:** hello@rugbyanalysis.com (Play shows it on the listing; it must reach you).

**Website:** `https://rugbyanalysis.com`

**Privacy policy:** `https://rugbyanalysis.com/privacy`

## App content (Policy > App content)

- **Privacy policy:** `https://rugbyanalysis.com/privacy`
- **Ads:** No, the app doesn't contain ads.
- **App access:** All functionality is available without special access (no sign-in).
- **Content rating:** Category "All other app types". Answer No to violence, sexual content, language, controlled substances, crude humour and gambling (the model's picks are predictions, with no betting, odds from bookmakers or real or simulated gambling). **Users can interact: Yes** (private chat rooms with friends they invite; there's in-app reporting and hiding of messages). The app doesn't share the user's location, and there are no purchases. *Changed in 114: redo the questionnaire when 114 goes to a track.*
- **Target audience:** 13 and over (13 to 15, 16 to 17, 18 and over). Not "appeals to children". This keeps it out of the Families programme.
- **News app:** No. **COVID-19, health, financial features, government app:** No / none.
- **Data deletion:** Yes, users can ask for their data to be deleted: `https://rugbyanalysis.com/delete-data` (in the app: Me > Your data > Delete my data).

## Data safety form

- Does your app collect or share any of the required user data types? **Yes.**
- Is all of the user data collected by your app encrypted in transit? **Yes.**
- Which of the following methods of account creation does your app support? **None** (the anonymous ID isn't an account people create).
- Do you provide a way for users to request that their data is deleted? **Yes**, `https://rugbyanalysis.com/delete-data`.

| Data type | Collected | Shared | Processed ephemerally? | Required or optional | Why |
|---|---|---|---|---|---|
| Personal info: User IDs (the anonymous sign-in ID) | Yes | No | No | Required | App functionality |
| App activity: Other user-generated content (teams followed, alert settings, match reminders) | Yes | No | No | Optional (works without following anyone) | App functionality, Personalisation |
| Device or other IDs (the notification token, only with alerts on) | Yes | No | No | Optional | App functionality |
| Personal info: Name (the display name picked for chat; can be a nickname) | Yes | No | No | Optional | App functionality |
| Messages: Other in-app messages (chat messages, deleted after 30 days) | Yes | No | No | Optional | App functionality |

From 114 (chat): add the last two rows in Play Console before 114 goes to any track. Everything else (location, email, contacts, photos, app usage analytics, crash logs): **not collected**.
"Shared" means given to another company for its own use. Google Firebase is a service provider, so it doesn't count as sharing.

## Closed testing (needed before production on a personal account)

Google needs at least 12 testers opted in for 14 days in a row before it lets a personal account apply for production.

1. **Test and release > Testing > Closed testing > Create track** (or use the default "Closed testing - Alpha").
2. **Testers:** tick the same email list you use for Smack Bang. Copy the opt-in link for the track and send it to them; each tester must open it and tap *Become a tester* (the same Google account as on their phone).
3. **Countries / regions:** United Kingdom and South Africa at least; International rugby works anywhere, so "All countries" is fine.
4. **Create release:** upload `RugbyAnalysis.aab`, from the latest **App APK** run on GitHub (Actions > App APK > the run > Artifacts). Use Play App Signing (Google's default).
5. **Release notes:**

```
<en-GB>
First test release: matchday picks, tournament tables and predictions, Rugby World Cup 2027 scenarios, and alerts for your teams.
</en-GB>
```

6. **Review release > Start rollout to Closed testing.** Google reviews it (usually a few hours to a few days).

After 14 days with 12 or more testers: **Dashboard > Apply for production access**, answer the questions about the test, then create a production release with the same bundle.
