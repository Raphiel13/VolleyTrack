import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final ratingsRepositoryProvider = Provider<RatingsRepository>((ref) {
  return RatingsRepository(FirebaseFirestore.instance);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class RatingsRepository {
  final FirebaseFirestore _db;

  RatingsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _db.collection('ratings');

  // RATINGS
  // Oceny graczy są celowo niezmienne — raz wystawiona ocena nie może zostać zmieniona ani usunięta

  // Sprawdzenie czy użytkownik już ocenił daną grę — zapobieganie podwójnym ocenom
  Future<bool> hasRated({
    required String gameId,
    required String raterId,
  }) async {
    final snap = await _ratings
        .where('gameId', isEqualTo: gameId)
        .where('raterId', isEqualTo: raterId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // Zapis oceny — dokument niemodyfikowalny po zapisaniu (wymuszone regułami Firestore)
  Future<void> saveRating({
    required String gameId,
    required String raterId,
    required String organizerId,
    required int rating,
  }) {
    return _ratings.add({
      'gameId': gameId,
      'raterId': raterId,
      'organizerId': organizerId,
      'rating': rating,
      'createdAt': Timestamp.now(),
    });
  }
}
