// Chat rooms for friends: plain Dart, no Firebase, so the tests can check it directly.
//
// A room lives at rooms/{id} in Firestore; its id is also the invite code (12 letters and
// digits, hard to guess). Messages live at rooms/{id}/messages and are deleted after 30 days.

import 'dart:math';

import 'clubs.dart';
import 'feeds.dart';

/// Messages are deleted this long after they're sent (a Firestore TTL policy on `deleteAt`).
const keepMessagesFor = Duration(days: 30);

/// A room nobody has written in for this long is deleted (TTL on rooms.deleteAt).
const keepQuietRoomsFor = Duration(days: 90);

const maxMessageLength = 500;
const maxNameLength = 24;
const maxRoomNameLength = 40;
const maxRoomMembers = 50;

/// The website page that opens an invite in the app (or sends you to Google Play).
const inviteSite = 'https://rugbyanalysis.com/join/';

// No 0/O, 1/I/L: codes are read aloud and typed in.
const _codeLetters = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const codeLength = 12;

String newRoomCode([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes(List.generate(codeLength, (_) => _codeLetters.codeUnitAt(r.nextInt(_codeLetters.length))));
}

/// The code in whatever someone pasted: a whole invite link, the message it came in, or the code
/// itself with spaces or dashes. Null when there's no code in it.
String? parseRoomCode(String text) {
  final link = RegExp(r'join/([A-Za-z0-9-]{12,16})').firstMatch(text);
  final raw = (link?.group(1) ?? text).toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  final m = RegExp('^[$_codeLetters]{$codeLength}\$').firstMatch(raw);
  return m?.group(0);
}

/// The code in an app route from an invite link ('/join/ABCDEFGHJKMN', or the whole
/// 'rugbyanalysis://app/join/...' on some phones). Null for any other route.
String? joinCodeFromRoute(String? route) {
  if (route == null) return null;
  final m = RegExp(r'/join/([A-Za-z0-9-]+)/?(?:[?#].*)?$').firstMatch(route);
  return m == null ? null : parseRoomCode(m.group(1)!);
}

/// 'ABCD-EFGH-JKMN', easier to read out.
String spacedCode(String code) =>
    code.length == codeLength ? '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8)}' : code;

String inviteLink(String code) => '$inviteSite$code';

/// A display name, tidied: spaces squashed and trimmed. Null when it can't be used.
String? cleanName(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty || t.length > maxNameLength) return null;
  return t;
}

/// The match a room is watching together: a Test (from the matchday feed) or a club game.
class PinnedMatch {
  const PinnedMatch({required this.kind, required this.date, required this.home, required this.away, this.kickOff, this.comp = ''});

  /// kind: 'm' or 'w' for a men's or women's Test, 'c' for a club game (home and away are club ids).
  factory PinnedMatch.test(Gender g, Fixture f) =>
      PinnedMatch(kind: g.key, date: f.date, home: f.home, away: f.away, kickOff: f.kickOff, comp: f.comp);

  /// [comp] is the competition's code ('URC'); a club's own games carry it already.
  factory PinnedMatch.club(ClubGame g, {String? comp}) =>
      PinnedMatch(kind: 'c', date: g.date, home: g.home, away: g.away, kickOff: g.kickOff, comp: comp ?? g.comp);

  static PinnedMatch? fromMap(Object? x) {
    if (x is! Map) return null;
    final kind = '${x['k'] ?? ''}', h = '${x['h'] ?? ''}', a = '${x['a'] ?? ''}';
    if (!['m', 'w', 'c'].contains(kind) || h.isEmpty || a.isEmpty) return null;
    return PinnedMatch(
      kind: kind,
      date: '${x['d'] ?? ''}',
      home: h,
      away: a,
      kickOff: x['ko'] is String ? DateTime.tryParse(x['ko'] as String) : null,
      comp: '${x['c'] ?? ''}',
    );
  }

  Map<String, Object?> toMap() =>
      {'k': kind, 'd': date, 'h': home, 'a': away, if (kickOff != null) 'ko': kickOff!.toUtc().toIso8601String(), if (comp.isNotEmpty) 'c': comp};

  final String kind;
  final String date;
  final String home;
  final String away;
  final DateTime? kickOff;
  final String comp;

  bool get isClub => kind == 'c';
  Gender get gender => Gender.fromKey(kind);
  String get key => '$kind|$date|$home|$away';

  @override
  bool operator ==(Object other) => other is PinnedMatch && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.members,
    this.names = const {},
    this.match,
    this.lastAt,
    this.lastText = '',
    this.lastName = '',
    this.lastUid = '',
    this.muted = const [],
  });

  /// From a Firestore document; [toDate] turns its timestamps into DateTimes (Firestore's Timestamp
  /// type isn't available here, so the backend hands in the conversion).
  factory Room.fromMap(String id, Map<String, dynamic> d, DateTime? Function(Object?) toDate) => Room(
        id: id,
        name: '${d['name'] ?? 'Chat'}',
        ownerUid: '${d['ownerUid'] ?? ''}',
        members: [for (final m in (d['members'] as List? ?? const [])) '$m'],
        names: {for (final e in ((d['names'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
        match: PinnedMatch.fromMap(d['match']),
        lastAt: toDate(d['lastAt']),
        lastText: '${d['lastText'] ?? ''}',
        lastName: '${d['lastName'] ?? ''}',
        lastUid: '${d['lastUid'] ?? ''}',
        muted: [for (final m in (d['muted'] as List? ?? const [])) '$m'],
      );

  final String id; // also the invite code
  final String name;
  final String ownerUid;
  final List<String> members;
  final Map<String, String> names; // uid -> display name
  final PinnedMatch? match;
  final DateTime? lastAt;
  final String lastText;
  final String lastName;
  final String lastUid; // who sent the last message
  final List<String> muted; // members who don't want alerts from this room

  bool isMember(String uid) => members.contains(uid);
  bool isOwner(String uid) => ownerUid == uid;
  bool get isFull => members.length >= maxRoomMembers;

  /// The others in the room, by name: 'Sipho, Tom and Ana', or 'Just you so far'.
  String peopleLine(String me) {
    final others = [for (final m in members) if (m != me) names[m] ?? 'Someone'];
    if (others.isEmpty) return 'Just you so far';
    if (others.length == 1) return 'You and ${others.first}';
    if (others.length <= 3) return 'You, ${others.sublist(0, others.length - 1).join(', ')} and ${others.last}';
    return 'You and ${others.length} others';
  }
}

class ChatMessage {
  const ChatMessage({required this.id, required this.uid, required this.name, required this.text, this.at});

  factory ChatMessage.fromMap(String id, Map<String, dynamic> d, DateTime? Function(Object?) toDate) =>
      ChatMessage(id: id, uid: '${d['uid'] ?? ''}', name: '${d['name'] ?? ''}', text: '${d['text'] ?? ''}', at: toDate(d['at']));

  final String id;
  final String uid;
  final String name;
  final String text;
  final DateTime? at; // null for a moment while the server stamps it
}

/// Rooms with the most recent conversation first (new rooms with no messages at the top).
List<Room> sortRooms(Iterable<Room> rooms) {
  final out = [...rooms];
  out.sort((a, b) {
    final x = a.lastAt, y = b.lastAt;
    if (x == null && y == null) return a.name.compareTo(b.name);
    if (x == null) return -1;
    if (y == null) return 1;
    return y.compareTo(x);
  });
  return out;
}

/// 'Just now', '5 min', '14:10', 'Yesterday', 'Sat 7 Nov', for a message time in the phone's clock.
String chatTime(DateTime t, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal(), l = t.toLocal();
  final d = n.difference(l);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(l.year, l.month, l.day)).inDays;
  if (days == 0) return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  if (days == 1) return 'Yesterday';
  const dn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dn[l.weekday - 1]} ${l.day} ${mn[l.month - 1]}';
}

/// The invite text shared from the room.
String inviteMessage(Room room, String fromName) {
  final watch = room.match == null ? '' : ' to watch the rugby';
  return '$fromName has invited you to “${room.name}” on RugbyAnalysis$watch. '
      'Tap to join: ${inviteLink(room.id)}\n(Or open the app, go to Chat and enter the code ${spacedCode(room.id)}.)';
}
