import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alerts.dart';
import '../models/chat.dart';
import '../models/clubs.dart';
import '../models/feeds.dart';
import '../services/backend.dart';
import '../services/chat_service.dart';
import '../services/feed_service.dart';

/// The app's single source of truth (Smack Bang's pattern): the feeds, which
/// side you're looking at, your teams and your alert settings. Screens read it
/// through [AppScope] and rebuild when it calls notifyListeners(), a bit like
/// an observable object in Python UI code.
class AppController extends ChangeNotifier {
  AppController({required this.source, this.backend, ChatService? chat, this.enableAlerts, this.disableAlerts, this.refreshAlerts})
      : chat = chat ?? backend?.chat;

  final FeedSource source;
  final Backend? backend; // null: Firebase isn't set up, so everything stays on the phone

  /// Chat rooms; null without a connection to the server (chat needs one).
  final ChatService? chat;

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
  ClubsFeed? clubs; // loaded on its own, so a problem with it never hides the Tests
  bool loading = false;
  String? error;
  Gender gender = Gender.men;
  Set<String> follows = {};

  /// Clubs you follow, by id ('leinster'), in the order you added them. Kept apart from [follows]
  /// (nations, which the server's alerts read) and saved as `clubs` on your record.
  Set<String> clubFollows = {};
  AlertPrefs alerts = const AlertPrefs();

  /// The tab showing (see [AppTab]); a notification about a chat message switches to Chat.
  int tab = AppTab.matchday;

  void setTab(int t) {
    if (t == tab) return;
    tab = t;
    notifyListeners();
  }

  bool get ready => matchday != null && tournaments != null;

  static const _followsKey = 'follows';
  static const _alertsKey = 'alerts';
  static const _clubsKey = 'clubs';
  static const _nameKey = 'chatName';
  static const _blockedKey = 'blocked';
  static const _seenKey = 'chatSeen';
  static const _showAllKey = 'showAllTests';
  static const minorCutoff = 12;

  /// Loads your saved teams and settings, then the feeds.
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    follows = {...?prefs.getStringList(_followsKey)};
    clubFollows = {...?prefs.getStringList(_clubsKey)};
    myName = prefs.getString(_nameKey);
    blocked = {...?prefs.getStringList(_blockedKey)};
    final seen = prefs.getString(_seenKey);
    if (seen != null) _seen = {for (final e in (jsonDecode(seen) as Map).entries) '${e.key}': (e.value as num).toInt()};
    showAllTests = prefs.getBool(_showAllKey) ?? false;
    final saved = prefs.getString(_alertsKey);
    if (saved != null) alerts = AlertPrefs.fromMap((jsonDecode(saved) as Map).cast<String, dynamic>());
    // With an account, the server copy wins (e.g. after reinstalling the app).
    try {
      final profile = await backend?.loadProfile();
      if (profile != null) {
        follows = {for (final f in (profile['follows'] as List? ?? const [])) '$f'};
        if (profile['clubs'] is List) clubFollows = {for (final f in profile['clubs'] as List) '$f'};
        if (profile['name'] is String) myName = profile['name'] as String;
        if (profile['alerts'] is Map) alerts = AlertPrefs.fromMap((profile['alerts'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('Could not load your saved teams: $e');
    }
    notifyListeners();
    _watchRooms();
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
    await _loadClubs();
  }

  Future<void> _loadClubs() async {
    try {
      clubs = ClubsFeed.fromJson(await source.load('clubs'));
    } catch (e) {
      debugPrint('Clubs feed: $e');
    }
    notifyListeners();
  }

  bool isFollowingClub(String id) => clubFollows.contains(id);

  void toggleClub(String id) {
    clubFollows = {...clubFollows};
    if (!clubFollows.remove(id)) clubFollows.add(id);
    _changed();
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

  // ---- Chat ----------------------------------------------------------------

  /// Your display name in chat rooms (null until you pick one).
  String? myName;

  /// Rooms you're in, newest conversation first.
  List<Room> rooms = const [];
  bool roomsLoaded = false;

  /// People whose messages you've hidden (their uids), on this phone only.
  Set<String> blocked = {};

  Map<String, int> _seen = {}; // room id -> when you last looked (ms since 1970)
  StreamSubscription<List<Room>>? _roomsSub;

  bool get chatAvailable => chat != null && !_deleted;
  String? get myUid => chat?.uid;

  void _watchRooms() {
    if (chat == null || _roomsSub != null) return;
    _roomsSub = chat!.rooms().listen((r) {
      rooms = r;
      roomsLoaded = true;
      notifyListeners();
    }, onError: (Object e) {
      roomsLoaded = true;
      debugPrint('Chat rooms: $e');
      notifyListeners();
    });
  }

  Room? room(String id) {
    for (final r in rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// A message you haven't seen yet, from someone else.
  bool hasUnread(Room r) =>
      r.lastAt != null && r.lastUid != myUid && r.lastAt!.millisecondsSinceEpoch > (_seen[r.id] ?? 0) && !blocked.contains(r.lastUid);

  int get unreadRooms => rooms.where(hasUnread).length;

  void markSeen(String roomId) {
    _seen = {..._seen, roomId: DateTime.now().millisecondsSinceEpoch};
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_seenKey, jsonEncode(_seen))).catchError((Object e) {
      debugPrint('Could not save what you have read: $e');
      return false;
    });
  }

  Future<void> setMyName(String name) async {
    final n = cleanName(name);
    if (n == null || n == myName) return;
    myName = n;
    _changed();
    await chat?.updateMyName([for (final r in rooms) r.id], n);
  }

  /// Makes a room and asks to show alerts for it. Returns the new room.
  Future<Room> createRoom(String name, {PinnedMatch? match}) async {
    final r = await chat!.create(name: name.trim(), myName: myName!, match: match);
    if (!rooms.any((x) => x.id == r.id)) rooms = sortRooms([...rooms, r]);
    notifyListeners();
    _offerAlerts();
    return r;
  }

  /// Joins the room with [code]. Returns it, or throws a [ChatException] that says what went wrong.
  Future<Room> joinRoom(String code) async {
    final Room? r;
    try {
      r = await chat!.find(code);
    } catch (e) {
      debugPrint('Find room: $e');
      throw const ChatException('Couldn’t reach the chat. Check your connection and try again.');
    }
    if (r == null) throw const ChatException('There’s no room with that code. It may have been deleted.');
    if (r.isMember(chat!.uid)) return r;
    if (r.isFull) throw const ChatException('That room is full ($maxRoomMembers people).');
    try {
      await chat!.join(r.id, myName!);
    } catch (e) {
      debugPrint('Join room: $e');
      throw const ChatException('Couldn’t join that room. Try again in a moment.');
    }
    _offerAlerts();
    return r;
  }

  Future<void> send(Room r, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await chat!.send(r.id, myName ?? 'Someone', t.length > maxMessageLength ? t.substring(0, maxMessageLength) : t);
    markSeen(r.id);
  }

  Future<void> leaveRoom(Room r) async {
    await (r.isOwner(chat!.uid) && r.members.length <= 1 ? chat!.delete(r.id) : chat!.leave(r.id));
    rooms = [for (final x in rooms) if (x.id != r.id) x];
    notifyListeners();
  }

  Future<void> deleteRoom(Room r) async {
    await chat!.delete(r.id);
    rooms = [for (final x in rooms) if (x.id != r.id) x];
    notifyListeners();
  }

  Future<void> pinMatch(Room r, PinnedMatch? m) => chat!.pin(r.id, m);
  Future<void> renameRoom(Room r, String name) => chat!.rename(r.id, name.trim());
  Future<void> muteRoom(Room r, bool muted) => chat!.setMuted(r.id, muted);
  Future<void> deleteMessage(Room r, ChatMessage m) => chat!.deleteMessage(r.id, m.id);

  /// Reports a message and hides everything from its sender on this phone.
  Future<void> report(Room r, ChatMessage m, String reason) async {
    await chat!.report(r.id, m, reason);
    block(m.uid);
  }

  void block(String uid) {
    blocked = {...blocked, uid};
    _saveBlocked();
  }

  void unblock(String uid) {
    blocked = {...blocked}..remove(uid);
    _saveBlocked();
  }

  void _saveBlocked() {
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setStringList(_blockedKey, blocked.toList())).catchError((Object e) {
      debugPrint('Could not save who you have hidden: $e');
      return false;
    });
  }

  /// After you create or join a room, ask once whether to show alerts (they bring chat messages too).
  void _offerAlerts() {
    if (!alerts.on) turnOnAlerts();
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    super.dispose();
  }

  /// Deletes your teams and settings from the server and this phone. Throws if
  /// the server copy couldn't be deleted (no connection), so the screen can say so.
  Future<void> deleteMyData() async {
    await chat?.forgetMe();
    await backend?.deleteEverything();
    await _roomsSub?.cancel();
    _roomsSub = null;
    rooms = const [];
    myName = null;
    blocked = {};
    _seen = {};
    _deleted = true;
    await disableAlerts?.call();
    follows = {};
    clubFollows = {};
    alerts = const AlertPrefs();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_followsKey);
    await prefs.remove(_clubsKey);
    for (final k in [_nameKey, _blockedKey, _seenKey]) {
      await prefs.remove(k);
    }
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
      await prefs.setStringList(_clubsKey, clubFollows.toList());
      if (myName != null) await prefs.setString(_nameKey, myName!);
      await prefs.setString(_alertsKey, jsonEncode(alerts.toMap()));
      if (_deleted) return;
      await backend?.saveProfile(
          follows: follows.toList(), clubs: clubFollows.toList(), name: myName, alerts: alerts.toMap(), utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes);
    } catch (e) {
      debugPrint('Could not save your teams: $e');
    }
  }
}

/// The tabs, in order.
abstract final class AppTab {
  static const matchday = 0, tournaments = 1, clubs = 2, chat = 3, me = 4;
}

/// A chat problem, in words to show the person.
class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Makes the controller available to every screen below it.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// Use in build(): the widget rebuilds when the controller changes.
  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Use in button handlers (doesn't subscribe to rebuilds).
  static AppController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
