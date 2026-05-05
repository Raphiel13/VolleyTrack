import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

// Połączenie strumienia uwierzytelnienia z dokumentem Firestore —
// profil aktualizuje się automatycznie gdy zmienia się stan logowania
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

// Wariant rodzinny — pobieranie profilu dowolnego użytkownika po uid
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

  // Pomijanie snapshotów gdzie dokument jeszcze nie istnieje — unikanie null w UI
  Stream<UserProfile> watchUser(String uid) {
    return _doc(uid)
        .snapshots()
        .where((snap) => snap.exists)
        .map(_fromDoc);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  // Zapisywanie profilu z opcją merge — brak nadpisywania pól nieobecnych w mapie
  Future<void> saveUser(UserProfile user) {
    return _doc(user.id).set(_toMap(user), SetOptions(merge: true));
  }

  // Tworzenie dokumentu tylko przy pierwszym logowaniu —
  // priorytet nazwy: displayName → prefiks e-mail → wartość domyślna 'Gracz'
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

  // RATINGS
  // Przeliczenie średniej oceny organizatora po każdej nowej ocenie —
  // oceny są niezmienne, więc wystarczy zsumowanie wszystkich i podzielenie przez liczbę
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
      // Zaokrąglenie do jednego miejsca po przecinku przed zapisem
      'organizerRating': double.parse(avg.toStringAsFixed(1)),
    });
  }

  // ── Backward-compatible aliases ────────────────────────────────────────────

  Stream<UserProfile> getUser(String uid) => watchUser(uid);
  Future<void> updateUser(UserProfile profile) => saveUser(profile);

  Future<void> createUserProfile(User firebaseUser) {
    return createUserIfNotExists(
      firebaseUser.uid,
      firebaseUser.displayName ?? '',
      firebaseUser.email ?? '',
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  // Deserializacja dokumentu Firestore do modelu — bezpieczne rzutowanie z wartościami domyślnymi
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
        // Brak zapisu photoUrl gdy null — zachowanie istniejącego zdjęcia
        if (p.photoUrl != null) 'photoUrl': p.photoUrl,
      };

  // Parsowanie enumu bezpiecznie — nieznana wartość wraca do pierwszego elementu listy
  T _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return values.first;
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () => values.first,
    );
  }
}
