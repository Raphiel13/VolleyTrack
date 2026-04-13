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

// ─── Repository ───────────────────────────────────────────────────────────────

class GameRepository {
  final FirebaseFirestore _db;

  GameRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');

  /// Streams all open games with a future date, ordered by dateTime.
  Stream<List<NearbyGame>> watchOpenGames() {
    return _games
        .where('isOpen', isEqualTo: true)
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Adds a new game document. The id from Firestore is set on the returned game.
  Future<NearbyGame> createGame(NearbyGame game) async {
    final doc = await _games.add(_toMap(game));
    return game._withId(doc.id);
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

  // ─── Serialization ──────────────────────────────────────────────────────────

  NearbyGame _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return NearbyGame(
      id: doc.id,
      title: d['title'] as String,
      location: d['location'] as String,
      dateTime: (d['dateTime'] as Timestamp).toDate(),
      level: PlayerLevel.values.byName(d['level'] as String),
      category: GameCategory.values.byName(d['category'] as String),
      spotsTotal: d['spotsTotal'] as int,
      spotsTaken: d['spotsTaken'] as int,
      organizerName: d['organizerName'] as String? ?? '',
      organizerRating: (d['organizerRating'] as num?)?.toDouble() ?? 0.0,
      // distanceKm is not stored in Firestore — computed from geo elsewhere
      distanceKm: 0.0,
    );
  }

  Map<String, dynamic> _toMap(NearbyGame g) => {
        'title': g.title,
        'location': g.location,
        'dateTime': Timestamp.fromDate(g.dateTime),
        'level': g.level.name,
        'category': g.category.name,
        'spotsTotal': g.spotsTotal,
        'spotsTaken': g.spotsTaken,
        'organizerName': g.organizerName,
        'organizerRating': g.organizerRating,
        'isOpen': !g.isFull,
        'playerIds': <String>[],
      };
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

// ─── NearbyGame extension (internal) ─────────────────────────────────────────

extension _NearbyGameX on NearbyGame {
  NearbyGame _withId(String id) => NearbyGame(
        id: id,
        title: title,
        location: location,
        dateTime: dateTime,
        level: level,
        category: category,
        spotsTotal: spotsTotal,
        spotsTaken: spotsTaken,
        distanceKm: distanceKm,
        organizerName: organizerName,
        organizerRating: organizerRating,
      );
}
