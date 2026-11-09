import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../firebase_options.dart';
import 'chat_service.dart';

/// The same Firebase project as Smack Bang (middle-509820), with this app's
/// own Firestore database, so the two apps never see each other's data.
/// Create it once in the Firebase console: Firestore > Add database > "rugbydb".
const firestoreDatabaseId = 'rugbydb';

/// Everything that talks to Firebase, in one place (as in Smack Bang):
/// anonymous sign-in, your teams, clubs, chat name and alert settings at users/{uid}, and this
/// phone's notification token at devices/{uid} (chat itself is in chat_service.dart). The server reads both to send
/// the weekend heads-up and kick-off reminders (functions/main.py).
/// Records unused for this long are deleted by a Firestore TTL policy on `deleteAt`
/// (users and devices in rugbydb). The date moves forward every time the app opens.
const keepUnusedFor = Duration(days: 365);

Timestamp _deleteAt() => Timestamp.fromDate(DateTime.now().add(keepUnusedFor));

class Backend {
  Backend._(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  /// Starts Firebase and signs in anonymously. Returns null when Firebase
  /// can't start (not set up yet, offline, or in tests): the app then keeps
  /// everything on the phone.
  static Future<Backend?> connect({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(timeout);
      final auth = FirebaseAuth.instance;
      final user = await auth.authStateChanges().first.timeout(timeout) ?? (await auth.signInAnonymously().timeout(timeout)).user!;
      return Backend._(FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: firestoreDatabaseId), user.uid);
    } catch (e) {
      debugPrint('Firebase not started: $e');
      return null;
    }
  }

  /// Chat rooms and messages (chat_service.dart), in the same database.
  late final ChatService chat = FirestoreChat(_db, uid);

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);

  /// Your saved teams and alert settings, or null if you have none yet.
  Future<Map<String, dynamic>?> loadProfile() async => (await _user.get()).data();

  /// [utcOffsetMinutes] is the phone's clock offset (60 for UK summer time),
  /// so the server can write kick-off times in your time. It's re-saved each
  /// time the app opens, which keeps it right across clock changes.
  Future<void> saveProfile({required List<String> follows, List<String> clubs = const [], String? name, required Map<String, Object?> alerts, required int utcOffsetMinutes}) =>
      _user.set({
        'follows': follows,
        'clubs': clubs,
        if (name != null) 'name': name,
        'alerts': alerts,
        'utcOffsetMinutes': utcOffsetMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
        'deleteAt': _deleteAt(),
      });

  /// "Delete my data": removes your teams, alert settings and phone token from the
  /// server, then the anonymous sign-in itself. The next launch starts afresh.
  Future<void> deleteEverything() async {
    await _db.collection('devices').doc(uid).delete();
    await _user.delete();
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (e) {
      debugPrint('Could not remove the sign-in: $e'); // the data is gone either way
    }
  }

  Future<void> saveDeviceToken(String token) => _db.collection('devices').doc(uid).set({
        'token': token,
        'platform': kIsWeb ? 'web' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
        'deleteAt': _deleteAt(),
      });
}
