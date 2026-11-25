import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/home_state.dart';

/// User records and roles in `/users/{uid}` (admin / user).
///
/// The database rules let a user create their own record with role "user"
/// only; only an admin can promote someone to admin.
class UserService {
  UserService({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance;
  final FirebaseDatabase _db;

  DatabaseReference _ref(String uid) => _db.ref('users/$uid');

  /// Creates the user's record on first login. Never throws: if the rules
  /// are not deployed yet, the app simply treats the user as a normal user.
  Future<void> ensureRecord(User user) async {
    try {
      final snap = await _ref(user.uid).get();
      if (!snap.exists) {
        await _ref(user.uid).set({
          'email': user.email,
          'role': 'user',
          'createdAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint('ensureRecord: $e');
    }
  }

  Stream<AppUser> watch(User user) => _ref(user.uid).onValue.map(
        (e) => AppUser.fromMap(user.uid, asStringMap(e.snapshot.value),
            fallbackEmail: user.email),
      ).handleError((Object e) => debugPrint('watch user: $e'));

  /// All users (admins only, per the rules).
  Stream<List<AppUser>> watchAll() => _db.ref('users').onValue.map((e) {
        final list = <AppUser>[];
        asStringMap(e.snapshot.value).forEach((uid, v) {
          list.add(AppUser.fromMap(uid, asStringMap(v)));
        });
        list.sort((a, b) => a.email.compareTo(b.email));
        return list;
      });

  Future<void> setRole(String uid, String role) => _ref(uid).child('role').set(role);

  Future<void> saveFcmToken(String uid, String token) async {
    try {
      await _ref(uid).update({'fcmToken': token});
    } catch (e) {
      debugPrint('saveFcmToken: $e');
    }
  }
}
