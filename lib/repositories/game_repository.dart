import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(FirebaseFirestore.instance);
});

final openGamesProvider = StreamProvider<List<NearbyGame>>((ref) {
  return ref.watch(gameRepositoryProvider).watchOpenGames();
});

final publicGroupGamesProvider = StreamProvider<List<NearbyGame>>((ref) {
  return ref.watch(gameRepositoryProvider).watchPublicGroupGames();
});

// ─── Repository ───────────────────────────────────────────────────────────────

class GameRepository {
  final FirebaseFirestore _db;

  GameRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  /// Streams all open games with a future date, ordered by dateTime.
  Stream<List<NearbyGame>> watchOpenGames() {
    return _games
        .where('isOpen', isEqualTo: true)
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map(NearbyGame.fromFirestore).toList());
  }

  /// Streams public group events (isOpenToPublic == true) with a future date.
  Stream<List<NearbyGame>> watchPublicGroupGames() {
    return _events
        .where('isOpenToPublic', isEqualTo: true)
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              final lat = (d['latitude'] as num?)?.toDouble() ?? 52.2297;
              final lng = (d['longitude'] as num?)?.toDouble() ?? 21.0122;
              return NearbyGame(
                id: doc.id,
                title: d['groupName'] as String? ?? d['title'] as String? ?? 'Gra grupowa',
                location: d['location'] as String? ?? '',
                dateTime: (d['dateTime'] as Timestamp).toDate(),
                level: PlayerLevel.recreational,
                category: GameCategory.indoor,
                spotsTotal: (d['maxPlayers'] as num? ?? 10).toInt(),
                spotsTaken: (d['spotsTaken'] as num? ?? 0).toInt(),
                distanceKm: 0.0,
                latitude: lat,
                longitude: lng,
                organizerName: d['createdByName'] as String? ?? '',
                organizerRating:
                    (d['organizerRating'] as num?)?.toDouble() ?? 0.0,
                organizerId: d['createdBy'] as String? ?? '',
                isGroupEvent: true,
              );
            }).toList());
  }

  /// Adds a new game document. The id from Firestore is set on the returned game.
  Future<NearbyGame> createGame(NearbyGame game) async {
    final doc = await _games.add(game.toFirestore());
    return NearbyGame(
      id: doc.id,
      title: game.title,
      location: game.location,
      dateTime: game.dateTime,
      level: game.level,
      category: game.category,
      spotsTotal: game.spotsTotal,
      spotsTaken: game.spotsTaken,
      distanceKm: game.distanceKm,
      organizerName: game.organizerName,
      organizerRating: game.organizerRating,
    );
  }

  /// Adds [userId] to the game's playerIds list and increments spotsTaken.
  /// Throws [GameFullException] if no spots are left.
  Future<void> joinGame(String gameId, String userId) async {
    await _db.runTransaction((tx) async {
      final ref = _games.doc(gameId);
      final snap = await tx.get(ref);

      if (!snap.exists) throw GameNotFoundException(gameId);

      final data = snap.data()!;
      final spotsTaken = (data['spotsTaken'] as int? ?? 0);
      final spotsTotal = (data['spotsTotal'] as int? ?? 0);

      if (spotsTaken >= spotsTotal) throw GameFullException(gameId);

      final playerIds = List<String>.from(data['playerIds'] as List? ?? []);
      if (playerIds.contains(userId)) return; // already joined, idempotent

      tx.update(ref, {
        'playerIds': FieldValue.arrayUnion([userId]),
        'spotsTaken': FieldValue.increment(1),
      });
    });
  }

  /// Removes [userId] from the game's playerIds list and decrements spotsTaken.
  Future<void> leaveGame(String gameId, String userId) async {
    await _db.runTransaction((tx) async {
      final ref = _games.doc(gameId);
      final snap = await tx.get(ref);

      if (!snap.exists) throw GameNotFoundException(gameId);

      final data = snap.data()!;
      final playerIds = List<String>.from(data['playerIds'] as List? ?? []);
      if (!playerIds.contains(userId)) return; // not a participant, idempotent

      tx.update(ref, {
        'playerIds': FieldValue.arrayRemove([userId]),
        'spotsTaken': FieldValue.increment(-1),
      });
    });
  }

}

// ─── Exceptions ───────────────────────────────────────────────────────────────

class GameNotFoundException implements Exception {
  final String gameId;
  const GameNotFoundException(this.gameId);

  @override
  String toString() => 'GameNotFoundException: game $gameId not found';
}

class GameFullException implements Exception {
  final String gameId;
  const GameFullException(this.gameId);

  @override
  String toString() => 'GameFullException: game $gameId has no spots left';
}

