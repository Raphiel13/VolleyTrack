import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserStats {
  final int totalGames;
  final int wins;
  final double avgPoints;

  const UserStats({
    required this.totalGames,
    required this.wins,
    required this.avgPoints,
  });

  int get losses => totalGames - wins;

  double get winRate => totalGames == 0 ? 0.0 : wins / totalGames;

  static const empty = UserStats(totalGames: 0, wins: 0, avgPoints: 0.0);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(FirebaseFirestore.instance);
});

/// Family provider — pass the current user's uid.
/// Usage: `ref.watch(statsProvider('uid-here'))`
final statsProvider =
    StreamProvider.family<UserStats, String>((ref, userId) {
  return ref.watch(statsRepositoryProvider).watchStats(userId);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class StatsRepository {
  final FirebaseFirestore _db;

  StatsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  /// Streams a live [UserStats] computed from all match documents
  /// where `userId == userId`.
  Stream<UserStats> watchStats(String userId) {
    return _matches
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return UserStats.empty;

      int wins = 0;
      int totalPoints = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isWin'] == true) wins++;
        totalPoints += (data['points'] as num? ?? 0).toInt();
      }

      return UserStats(
        totalGames: snap.docs.length,
        wins: wins,
        avgPoints: totalPoints / snap.docs.length,
      );
    });
  }
}
