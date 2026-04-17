import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

/// Streams the current user's profile. Emits null when uid is empty.
final currentUserProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  if (uid.isEmpty) return const Stream.empty();
  return ref.watch(userRepositoryProvider).getUser(uid);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class UserRepository {
  final FirebaseFirestore _db;

  UserRepository(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// Creates a user profile document from a Firebase [User].
  /// Uses [setData] with merge:true — safe to call on both first sign-up
  /// and subsequent logins (won't overwrite existing custom data).
  Future<void> createUserProfile(User firebaseUser) async {
    final ref = _doc(firebaseUser.uid);
    final snap = await ref.get();

    if (snap.exists) return; // profile already initialised, nothing to do

    await ref.set({
      'name': firebaseUser.displayName?.trim().isNotEmpty == true
          ? firebaseUser.displayName!
          : firebaseUser.email?.split('@').first ?? 'Gracz',
      'bio': '',
      'level': PlayerLevel.recreational.name,
      'positions': <String>[],
      'themeMode': AppThemeMode.system.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams the [UserProfile] for [uid]. Emits an error if the document
  /// does not exist.
  Stream<UserProfile> getUser(String uid) {
    return _doc(uid)
        .snapshots()
        .where((snap) => snap.exists)
        .map(_fromDoc);
  }

  /// Overwrites mutable profile fields. Uses merge so a missing document
  /// is created rather than causing an error.
  Future<void> updateUser(UserProfile profile) {
    return _doc(profile.id).set(_toMap(profile), SetOptions(merge: true));
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  UserProfile _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserProfile(
      id: doc.id,
      name: d['name'] as String? ?? '',
      bio: d['bio'] as String? ?? '',
      level: _parseEnum(PlayerLevel.values, d['level'] as String?),
      positions: ((d['positions'] as List?)?.cast<String>() ?? [])
          .map((s) => _parseEnum(PlayerPosition.values, s))
          .toList(),
      themeMode: _parseEnum(AppThemeMode.values, d['themeMode'] as String?),
    );
  }

  Map<String, dynamic> _toMap(UserProfile p) => {
        'name': p.name,
        'bio': p.bio,
        'level': p.level.name,
        'positions': p.positions.map((pos) => pos.name).toList(),
        'themeMode': p.themeMode.name,
      };

  /// Parses an enum by name, falling back to [values.first] on unknown values.
  T _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return values.first;
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () => values.first,
    );
  }
}
