import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../firebase_options.dart';

/// The same Firebase project as Smack Bang (middle-509820), with this app's
/// own Firestore database, so the two apps never see each other's data.
/// Create it once in the Firebase console: Firestore > Add database > "rugbydb".
const firestoreDatabaseId = 'rugbydb';

/// Everything that talks to Firebase, in one place (as in Smack Bang):
/// anonymous sign-in, your teams and alert settings at users/{uid}, and this
/// phone's notification token at devices/{uid}. The server reads both to send
/// the weekend heads-up and kick-off reminders (functions/main.py).
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

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);

  /// Your saved teams and alert settings, or null if you have none yet.
  Future<Map<String, dynamic>?> loadProfile() async => (await _user.get()).data();

  /// [utcOffsetMinutes] is the phone's clock offset (60 for UK summer time),
  /// so the server can write kick-off times in your time. It's re-saved each
  /// time the app opens, which keeps it right across clock changes.
  Future<void> saveProfile({required List<String> follows, required Map<String, Object?> alerts, required int utcOffsetMinutes}) =>
      _user.set({
        'follows': follows,
        'alerts': alerts,
        'utcOffsetMinutes': utcOffsetMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> saveDeviceToken(String token) => _db.collection('devices').doc(uid).set({
        'token': token,
        'platform': kIsWeb ? 'web' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
