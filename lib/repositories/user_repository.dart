import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

/// Streams the current user's profile. Emits null when not signed in or
/// while the Firestore document doesn't exist yet.
final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
    data: (firebaseUser) {
      if (firebaseUser == null) return Stream.value(null);
      return ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);
    },
  );
});

/// Streams the current user's profile by uid (family variant).
/// Emits nothing when uid is empty.
final currentUserProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  if (uid.isEmpty) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class UserRepository {
  final FirebaseFirestore _db;

  UserRepository(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Streams the [UserProfile] for [uid] in real time.
  /// Skips snapshots where the document does not exist yet.
  Stream<UserProfile> watchUser(String uid) {
    return _doc(uid)
        .snapshots()
        .where((snap) => snap.exists)
        .map(_fromDoc);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Saves (creates or overwrites) mutable profile fields for [user].
  /// Uses merge so a missing document is created without error.
  Future<void> saveUser(UserProfile user) {
    return _doc(user.id).set(_toMap(user), SetOptions(merge: true));
  }

  /// Creates a profile document only when one doesn't exist yet.
  /// Uses [displayName] → [email] prefix → 'Gracz' as the initial name.
  Future<void> createUserIfNotExists(
      String uid, String displayName, String email) async {
    final ref = _doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final name = displayName.trim().isNotEmpty
        ? displayName.trim()
        : email.split('@').first.isNotEmpty
            ? email.split('@').first
            : 'Gracz';

    await ref.set({
      'name': name,
      'bio': '',
      'level': PlayerLevel.recreational.name,
      'positions': <String>[],
      'themeMode': AppThemeMode.system.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Recomputes the average rating for [userId] from all 'ratings' documents
  /// and updates the 'organizerRating' field on their users document.
  Future<void> updateOrganizerRating(String userId) async {
    final snap = await _db
        .collection('ratings')
        .where('organizerId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return;
    final avg = snap.docs
            .map((d) => (d.data()['rating'] as num).toDouble())
            .fold(0.0, (a, b) => a + b) /
        snap.docs.length;
    await _doc(userId).update({
      'organizerRating': double.parse(avg.toStringAsFixed(1)),
    });
  }

  // ── Backward-compatible aliases ────────────────────────────────────────────

  /// Alias for [watchUser] — kept for existing call sites.
  Stream<UserProfile> getUser(String uid) => watchUser(uid);

  /// Alias for [saveUser] — kept for existing call sites.
  Future<void> updateUser(UserProfile profile) => saveUser(profile);

  /// Creates a profile from a Firebase [User] object.
  /// Delegates to [createUserIfNotExists].
  Future<void> createUserProfile(User firebaseUser) {
    return createUserIfNotExists(
      firebaseUser.uid,
      firebaseUser.displayName ?? '',
      firebaseUser.email ?? '',
    );
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
      photoUrl: d['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> _toMap(UserProfile p) => {
        'name': p.name,
        'bio': p.bio,
        'level': p.level.name,
        'positions': p.positions.map((pos) => pos.name).toList(),
        'themeMode': p.themeMode.name,
        if (p.photoUrl != null) 'photoUrl': p.photoUrl,
      };

  T _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return values.first;
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () => values.first,
    );
  }
}
