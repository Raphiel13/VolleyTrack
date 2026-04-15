import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

/// Aggregated season statistics computed from all match documents.
class UserStats {
  final int totalGames;
  final int wins;
  final double avgPoints;
  final int totalAces;
  final int totalBlocks;
  final int totalReceptions;
  final int totalErrors;

  /// Number of matches played on each day of the current calendar week.
  /// Keys: 'Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'
  final Map<String, int> weeklyActivity;

  const UserStats({
    required this.totalGames,
    required this.wins,
    required this.avgPoints,
    required this.totalAces,
    required this.totalBlocks,
    required this.totalReceptions,
    required this.totalErrors,
    required this.weeklyActivity,
  });

  int get losses => totalGames - wins;

  double get winRate => totalGames == 0 ? 0.0 : wins / totalGames;

  static final empty = UserStats(
    totalGames: 0,
    wins: 0,
    avgPoints: 0.0,
    totalAces: 0,
    totalBlocks: 0,
    totalReceptions: 0,
    totalErrors: 0,
    weeklyActivity: _emptyWeek(),
  );

  static Map<String, int> _emptyWeek() => {
        'Pn': 0,
        'Wt': 0,
        'Śr': 0,
        'Cz': 0,
        'Pt': 0,
        'Sb': 0,
        'Nd': 0,
      };
}

// ─── Providers ────────────────────────────────────────────────────────────────

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(FirebaseFirestore.instance);
});

/// Streams aggregated [UserStats] for [userId].
/// Usage: `ref.watch(statsProvider('uid-here'))`
final statsProvider =
    StreamProvider.family<UserStats, String>((ref, userId) {
  return ref.watch(statsRepositoryProvider).watchStats(userId);
});

/// Streams match history for [userId] ordered by dateTime descending.
/// Usage: `ref.watch(matchesProvider('uid-here'))`
final matchesProvider =
    StreamProvider.family<List<MatchRecord>, String>((ref, userId) {
  return ref.watch(statsRepositoryProvider).watchMatches(userId);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class StatsRepository {
  final FirebaseFirestore _db;

  StatsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  // ── Aggregated stats ───────────────────────────────────────────────────────

  /// Streams live [UserStats] computed from all match documents for [userId].
  Stream<UserStats> watchStats(String userId) {
    return _matches
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return UserStats.empty;

      int wins = 0;
      int totalPoints = 0;
      int totalAces = 0;
      int totalBlocks = 0;
      int totalReceptions = 0;
      int totalErrors = 0;
      final weeklyActivity = UserStats._emptyWeek();

      // Monday of the current calendar week (00:00:00 local time).
      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1), // weekday: 1=Mon … 7=Sun
      );
      final weekEnd = weekStart.add(const Duration(days: 7));

      for (final doc in snap.docs) {
        final d = doc.data();

        if (d['isWin'] == true) wins++;
        totalPoints += (d['points'] as num? ?? 0).toInt();
        totalAces += (d['aces'] as num? ?? 0).toInt();
        totalBlocks += (d['blocks'] as num? ?? 0).toInt();
        totalReceptions += (d['receptions'] as num? ?? 0).toInt();
        totalErrors += (d['errors'] as num? ?? 0).toInt();

        final dt = (d['dateTime'] as Timestamp?)?.toDate();
        if (dt != null && !dt.isBefore(weekStart) && dt.isBefore(weekEnd)) {
          final key = _weekdayKey(dt.weekday);
          weeklyActivity[key] = (weeklyActivity[key] ?? 0) + 1;
        }
      }

      return UserStats(
        totalGames: snap.docs.length,
        wins: wins,
        avgPoints: totalPoints / snap.docs.length,
        totalAces: totalAces,
        totalBlocks: totalBlocks,
        totalReceptions: totalReceptions,
        totalErrors: totalErrors,
        weeklyActivity: weeklyActivity,
      );
    });
  }

  // ── Match history ──────────────────────────────────────────────────────────

  /// Streams match history for [userId] ordered by dateTime descending.
  Stream<List<MatchRecord>> watchMatches(String userId) {
    return _matches
        .where('userId', isEqualTo: userId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              final dt = (d['dateTime'] as Timestamp?)?.toDate();
              return MatchRecord(
                id: doc.id,
                date: dt != null
                    ? '${dt.day} ${_monthName(dt.month)}'
                    : (d['date'] as String? ?? ''),
                opponent: d['opponent'] as String? ?? '',
                isWin: d['isWin'] as bool? ?? false,
                score: d['score'] as String? ?? '',
                points: (d['points'] as num? ?? 0).toInt(),
                aces: (d['aces'] as num? ?? 0).toInt(),
              );
            }).toList());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Maps Dart's [DateTime.weekday] (1 = Mon … 7 = Sun) to a Polish key.
  static String _weekdayKey(int weekday) => const {
        1: 'Pn',
        2: 'Wt',
        3: 'Śr',
        4: 'Cz',
        5: 'Pt',
        6: 'Sb',
        7: 'Nd',
      }[weekday]!;

  static String _monthName(int m) => const [
        '',
        'sty',
        'lut',
        'mar',
        'kwi',
        'maj',
        'cze',
        'lip',
        'sie',
        'wrz',
        'paź',
        'lis',
        'gru',
      ][m];
}
