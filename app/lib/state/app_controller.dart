import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alerts.dart';
import '../models/feeds.dart';
import '../services/backend.dart';
import '../services/feed_service.dart';

/// The app's single source of truth (Smack Bang's pattern): the feeds, which
/// side you're looking at, your teams and your alert settings. Screens read it
/// through [AppScope] and rebuild when it calls notifyListeners(), a bit like
/// an observable object in Python UI code.
class AppController extends ChangeNotifier {
  AppController({required this.source, this.backend, this.enableAlerts, this.disableAlerts, this.refreshAlerts});

  final FeedSource source;
  final Backend? backend; // null: Firebase isn't set up, so everything stays on the phone

  /// Asks the phone for permission to show alerts; null where alerts aren't
  /// supported (the web, tests). Returns true when allowed.
  final Future<bool> Function()? enableAlerts;

  /// Forgets this phone's alert token (null where alerts aren't supported).
  final Future<void> Function()? disableAlerts;

  /// Re-saves this phone's alert token without asking (null where alerts aren't supported).
  final Future<void> Function()? refreshAlerts;

  bool _deleted = false; // after "Delete my data", nothing more goes to the server this session

  MatchdayFeed? matchday;
  TournamentsFeed? tournaments;
  bool loading = false;
  String? error;
  Gender gender = Gender.men;
  Set<String> follows = {};
  AlertPrefs alerts = const AlertPrefs();

  bool get ready => matchday != null && tournaments != null;

  static const _followsKey = 'follows';
  static const _alertsKey = 'alerts';
  static const _showAllKey = 'showAllTests';
  static const minorCutoff = 12;

  /// Loads your saved teams and settings, then the feeds.
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    follows = {...?prefs.getStringList(_followsKey)};
    showAllTests = prefs.getBool(_showAllKey) ?? false;
    final saved = prefs.getString(_alertsKey);
    if (saved != null) alerts = AlertPrefs.fromMap((jsonDecode(saved) as Map).cast<String, dynamic>());
    // With an account, the server copy wins (e.g. after reinstalling the app).
    try {
      final profile = await backend?.loadProfile();
      if (profile != null) {
        follows = {for (final f in (profile['follows'] as List? ?? const [])) '$f'};
        if (profile['alerts'] is Map) alerts = AlertPrefs.fromMap((profile['alerts'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('Could not load your saved teams: $e');
    }
    notifyListeners();
    await refresh();
    _save(); // refreshes the clock offset the server uses, and the record's deleteAt
    if (alerts.on) refreshAlerts?.call();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([source.load('matchday'), source.load('tournaments')]);
      matchday = MatchdayFeed.fromJson(results[0]);
      tournaments = TournamentsFeed.fromJson(results[1]);
    } catch (e) {
      error = 'Couldn’t load the latest rugby. Check your connection and pull down to try again.';
      debugPrint('Feeds: $e');
    }
    loading = false;
    notifyListeners();
  }

  void setGender(Gender g) {
    if (g == gender) return;
    gender = g;
    notifyListeners();
  }

  bool isFollowing(Gender g, String team) => follows.contains(followKey(g, team));

  /// Your team: the first team you follow. It leads the weekend list and the Me tab; the others
  /// are "teams you follow". Kept as the order of [follows], so the server needs nothing new.
  String? get myTeamKey => follows.isEmpty ? null : follows.first;
  bool isMyTeam(Gender g, String team) => myTeamKey == followKey(g, team);

  void makeMyTeam(Gender g, String team) {
    final k = followKey(g, team);
    follows = {k, ...follows.where((x) => x != k)};
    _changed();
  }

  /// Matchday hides Tests between smaller nations unless you ask for them (see [isMinorTest]).
  bool showAllTests = false;

  void setShowAllTests(bool v) {
    showAllTests = v;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_showAllKey, v)).catchError((Object e) {
      debugPrint('Could not save the Matchday filter: $e');
      return false;
    });
  }

  /// A Test most people won't want in their list: neither side in the world top [minorCutoff]
  /// and neither one a team you follow.
  bool isMinorTest(Gender g, String home, String away) {
    if (isFollowing(g, home) || isFollowing(g, away)) return false;
    final side = matchday?.side(g);
    if (side == null) return false;
    bool top(String t) => (side.rankOf(t) ?? 999) <= minorCutoff;
    return !top(home) && !top(away);
  }

  void toggleFollow(Gender g, String team) {
    final k = followKey(g, team);
    follows = {...follows};
    if (!follows.remove(k)) follows.add(k);
    _changed();
  }

  /// Teams you follow on one side, in the order you added them.
  List<String> followed(Gender g) => [for (final k in follows) if (k.startsWith('${g.key}|')) k.substring(2)];

  void setAlerts(AlertPrefs a) {
    alerts = a;
    _changed();
  }

  /// Turns alerts on: asks the phone first where that's possible.
  Future<bool> turnOnAlerts() async {
    final ok = enableAlerts == null || await enableAlerts!();
    if (ok) setAlerts(alerts.copyWith(on: true));
    return ok;
  }

  bool hasReminder(Gender g, Fixture f) => alerts.reminders.contains(reminderKey(g, f));

  /// Adds or removes a one-off kick-off reminder for one match. Returns true if added.
  Future<bool> toggleReminder(Gender g, Fixture f) async {
    final k = reminderKey(g, f);
    final r = {...alerts.reminders};
    if (r.remove(k)) {
      setAlerts(alerts.copyWith(reminders: r));
      return false;
    }
    r.add(k);
    if (!alerts.on) await turnOnAlerts();
    setAlerts(alerts.copyWith(reminders: r, kickoffMinutes: alerts.kickoffMinutes == 0 ? 60 : null));
    return true;
  }

  /// This weekend's games worth watching (your teams, big games, reminders).
  List<WatchItem> weekend() => matchday == null ? const [] : nextWeekend(worthWatching(matchday!, follows, alerts));

  /// Deletes your teams and settings from the server and this phone. Throws if
  /// the server copy couldn't be deleted (no connection), so the screen can say so.
  Future<void> deleteMyData() async {
    await backend?.deleteEverything();
    _deleted = true;
    await disableAlerts?.call();
    follows = {};
    alerts = const AlertPrefs();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_followsKey);
    await prefs.remove(_alertsKey);
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_followsKey, follows.toList());
      await prefs.setString(_alertsKey, jsonEncode(alerts.toMap()));
      if (_deleted) return;
      await backend?.saveProfile(
          follows: follows.toList(), alerts: alerts.toMap(), utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes);
    } catch (e) {
      debugPrint('Could not save your teams: $e');
    }
  }
}

/// Makes the controller available to every screen below it.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// Use in build(): the widget rebuilds when the controller changes.
  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Use in button handlers (doesn't subscribe to rebuilds).
  static AppController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
