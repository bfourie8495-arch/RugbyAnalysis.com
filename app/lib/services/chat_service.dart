import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';

/// Everything chat needs from the server. The app uses [FirestoreChat]; tests and the review
/// screenshots use [MemoryChat], so the screens can be checked without Firebase.
abstract class ChatService {
  String get uid;

  /// The rooms you're in, newest conversation first, kept up to date.
  Stream<List<Room>> rooms();

  /// A room's messages, oldest first (the last [limit]), kept up to date.
  Stream<List<ChatMessage>> messages(String roomId, {int limit = 200});

  Future<Room> create({required String name, required String myName, PinnedMatch? match});

  /// The room with this code, or null if there isn't one (or it was deleted).
  Future<Room?> find(String code);

  Future<void> join(String roomId, String myName);
  Future<void> leave(String roomId);
  Future<void> delete(String roomId); // the owner only
  Future<void> send(String roomId, String myName, String text);
  Future<void> deleteMessage(String roomId, String messageId);
  Future<void> pin(String roomId, PinnedMatch? match);
  Future<void> rename(String roomId, String name);
  Future<void> setMuted(String roomId, bool muted);

  /// Your new display name, in each room you're in.
  Future<void> updateMyName(Iterable<String> roomIds, String myName);

  /// Sends a message to the moderation queue (reports/{id}), which only the server reads.
  Future<void> report(String roomId, ChatMessage message, String reason);

  /// "Delete my data": leaves every room (deleting the ones you own) and deletes your messages.
  Future<void> forgetMe();
}

DateTime? _date(Object? x) => x is Timestamp ? x.toDate() : null;
Timestamp _ahead(Duration d) => Timestamp.fromDate(DateTime.now().add(d));

/// Chat on Firestore (rugbydb): rooms/{id}, rooms/{id}/messages/{id}, reports/{id}. firestore.rules says
/// who may do what; functions/main.py sends the alerts for new messages.
class FirestoreChat implements ChatService {
  FirestoreChat(this._db, this.uid);

  final FirebaseFirestore _db;
  @override
  final String uid;

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('rooms');
  CollectionReference<Map<String, dynamic>> _messages(String id) => _rooms.doc(id).collection('messages');

  @override
  Stream<List<Room>> rooms() => _rooms
      .where('members', arrayContains: uid)
      .snapshots()
      .map((s) => sortRooms([for (final d in s.docs) Room.fromMap(d.id, d.data(), _date)]));

  @override
  Stream<List<ChatMessage>> messages(String roomId, {int limit = 200}) => _messages(roomId)
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: false)
      .map((s) => [
            for (final d in s.docs.reversed) ChatMessage.fromMap(d.id, d.data(serverTimestamps: ServerTimestampBehavior.estimate), _date)
          ]);

  @override
  Future<Room> create({required String name, required String myName, PinnedMatch? match}) async {
    // A fresh code that isn't in use (a clash is vanishingly unlikely, but cheap to check).
    var code = newRoomCode();
    while ((await _rooms.doc(code).get()).exists) {
      code = newRoomCode();
    }
    await _rooms.doc(code).set({
      'name': name,
      'ownerUid': uid,
      'members': [uid],
      'names': {uid: myName},
      'muted': <String>[],
      if (match != null) 'match': match.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'deleteAt': _ahead(keepQuietRoomsFor),
    });
    return Room(id: code, name: name, ownerUid: uid, members: [uid], names: {uid: myName}, match: match);
  }

  @override
  Future<Room?> find(String code) async {
    final d = await _rooms.doc(code).get();
    final data = d.data();
    return data == null ? null : Room.fromMap(d.id, data, _date);
  }

  @override
  Future<void> join(String roomId, String myName) => _rooms.doc(roomId).update({
        'members': FieldValue.arrayUnion([uid]),
        'names.$uid': myName,
      });

  @override
  Future<void> leave(String roomId) => _rooms.doc(roomId).update({
        'members': FieldValue.arrayRemove([uid]),
        'muted': FieldValue.arrayRemove([uid]),
        'names.$uid': FieldValue.delete(),
      });

  @override
  Future<void> delete(String roomId) async {
    // Messages first (members can't read a room's messages once it's gone), then the room.
    final msgs = await _messages(roomId).get();
    for (var i = 0; i < msgs.docs.length; i += 400) {
      final b = _db.batch();
      for (final d in msgs.docs.skip(i).take(400)) {
        b.delete(d.reference);
      }
      await b.commit();
    }
    await _rooms.doc(roomId).delete();
  }

  @override
  Future<void> send(String roomId, String myName, String text) {
    final b = _db.batch();
    b.set(_messages(roomId).doc(), {
      'uid': uid,
      'name': myName,
      'text': text,
      'at': FieldValue.serverTimestamp(),
      'deleteAt': _ahead(keepMessagesFor),
    });
    b.update(_rooms.doc(roomId), {
      'lastAt': FieldValue.serverTimestamp(),
      'lastText': text.length > 120 ? '${text.substring(0, 119)}…' : text,
      'lastName': myName,
      'lastUid': uid,
      'deleteAt': _ahead(keepQuietRoomsFor),
    });
    return b.commit();
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId) => _messages(roomId).doc(messageId).delete();

  @override
  Future<void> pin(String roomId, PinnedMatch? match) =>
      _rooms.doc(roomId).update({'match': match == null ? FieldValue.delete() : match.toMap()});

  @override
  Future<void> rename(String roomId, String name) => _rooms.doc(roomId).update({'name': name});

  @override
  Future<void> setMuted(String roomId, bool muted) => _rooms.doc(roomId).update({
        'muted': muted ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  @override
  Future<void> updateMyName(Iterable<String> roomIds, String myName) async {
    for (final id in roomIds) {
      await _rooms.doc(id).update({'names.$uid': myName});
    }
  }

  @override
  Future<void> report(String roomId, ChatMessage message, String reason) => _db.collection('reports').add({
        'by': uid,
        'room': roomId,
        'message': message.id,
        'uid': message.uid,
        'name': message.name,
        'text': message.text,
        'reason': reason,
        'at': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> forgetMe() async {
    final mine = await _rooms.where('members', arrayContains: uid).get();
    for (final r in mine.docs) {
      if (r.data()['ownerUid'] == uid) {
        await delete(r.id);
        continue;
      }
      final own = await _messages(r.id).where('uid', isEqualTo: uid).get();
      for (final m in own.docs) {
        await m.reference.delete();
      }
      await leave(r.id);
    }
  }
}

/// Chat kept in memory: for tests and screenshots (and nothing is sent anywhere).
class MemoryChat implements ChatService {
  MemoryChat({this.uid = 'me'});

  @override
  final String uid;

  final Map<String, Room> _rooms = {};
  final Map<String, List<ChatMessage>> _msgs = {};
  final _changes = StreamController<void>.broadcast();
  final List<String> reports = [];
  var _n = 0;

  /// Adds a room as if it already existed (tests, screenshots).
  void seed(Room room, [List<ChatMessage> messages = const []]) {
    _rooms[room.id] = room;
    _msgs[room.id] = [...messages];
    _changes.add(null);
  }

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<Room>> rooms() => _watch(() => sortRooms(_rooms.values.where((r) => r.isMember(uid))));

  @override
  Stream<List<ChatMessage>> messages(String roomId, {int limit = 200}) => _watch(() {
        final all = _msgs[roomId] ?? const [];
        return all.length > limit ? all.sublist(all.length - limit) : [...all];
      });

  Room _copy(Room r, {String? name, List<String>? members, Map<String, String>? names, PinnedMatch? match, bool clearMatch = false,
          DateTime? lastAt, String? lastText, String? lastName, String? lastUid, List<String>? muted}) =>
      Room(
        id: r.id,
        name: name ?? r.name,
        ownerUid: r.ownerUid,
        members: members ?? r.members,
        names: names ?? r.names,
        match: clearMatch ? null : match ?? r.match,
        lastAt: lastAt ?? r.lastAt,
        lastText: lastText ?? r.lastText,
        lastName: lastName ?? r.lastName,
        lastUid: lastUid ?? r.lastUid,
        muted: muted ?? r.muted,
      );

  void _put(Room r) {
    _rooms[r.id] = r;
    _changes.add(null);
  }

  @override
  Future<Room> create({required String name, required String myName, PinnedMatch? match}) async {
    final r = Room(id: newRoomCode(), name: name, ownerUid: uid, members: [uid], names: {uid: myName}, match: match);
    _msgs[r.id] = [];
    _put(r);
    return r;
  }

  @override
  Future<Room?> find(String code) async => _rooms[code];

  @override
  Future<void> join(String roomId, String myName) async {
    final r = _rooms[roomId]!;
    _put(_copy(r, members: {...r.members, uid}.toList(), names: {...r.names, uid: myName}));
  }

  @override
  Future<void> leave(String roomId) async {
    final r = _rooms[roomId]!;
    _put(_copy(r, members: [...r.members]..remove(uid), names: {...r.names}..remove(uid)));
  }

  @override
  Future<void> delete(String roomId) async {
    _rooms.remove(roomId);
    _msgs.remove(roomId);
    _changes.add(null);
  }

  @override
  Future<void> send(String roomId, String myName, String text) async {
    final now = DateTime.now();
    (_msgs[roomId] ??= []).add(ChatMessage(id: 'm${_n++}', uid: uid, name: myName, text: text, at: now));
    _put(_copy(_rooms[roomId]!, lastAt: now, lastText: text, lastName: myName, lastUid: uid));
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId) async {
    _msgs[roomId]?.removeWhere((m) => m.id == messageId);
    _changes.add(null);
  }

  @override
  Future<void> pin(String roomId, PinnedMatch? match) async => _put(_copy(_rooms[roomId]!, match: match, clearMatch: match == null));

  @override
  Future<void> rename(String roomId, String name) async => _put(_copy(_rooms[roomId]!, name: name));

  @override
  Future<void> setMuted(String roomId, bool muted) async {
    final r = _rooms[roomId]!;
    _put(_copy(r, muted: muted ? {...r.muted, uid}.toList() : ([...r.muted]..remove(uid))));
  }

  @override
  Future<void> updateMyName(Iterable<String> roomIds, String myName) async {
    for (final id in roomIds) {
      final r = _rooms[id]!;
      _put(_copy(r, names: {...r.names, uid: myName}));
    }
  }

  @override
  Future<void> report(String roomId, ChatMessage message, String reason) async => reports.add('${message.id}: $reason');

  @override
  Future<void> forgetMe() async {
    for (final r in [..._rooms.values]) {
      if (!r.isMember(uid)) continue;
      if (r.isOwner(uid)) {
        await delete(r.id);
      } else {
        _msgs[r.id]?.removeWhere((m) => m.uid == uid);
        await leave(r.id);
      }
    }
  }
}
