import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final confirmationsRepositoryProvider =
    Provider<ConfirmationsRepository>((ref) {
  return ConfirmationsRepository(FirebaseFirestore.instance);
});

/// Nasłuchiwanie statusu potwierdzenia bieżącego użytkownika dla terminu.
/// ID dokumentu = "${eventId}_${userId}" — zapis w czasie O(1).
final userConfirmProvider =
    StreamProvider.family<String?, (String, String)>((ref, params) {
  final (eventId, userId) = params;
  if (userId.isEmpty) return Stream.value(null);
  return ref
      .watch(confirmationsRepositoryProvider)
      .watchUserConfirmation(eventId, userId);
});

/// Nasłuchiwanie liczby potwierdzeń dla terminu ze statusem 'yes'.
final confirmedCountProvider =
    StreamProvider.family<int, String>((ref, eventId) {
  return ref
      .watch(confirmationsRepositoryProvider)
      .watchConfirmedCount(eventId);
});

/// Nasłuchiwanie potwierdzonych uczestników terminu jako pełnych profili.
final eventConfirmedProvider =
    StreamProvider.family<List<GroupMember>, (String, String)>(
        (ref, params) {
  final (eventId, adminId) = params;
  if (eventId.isEmpty) return Stream.value([]);
  final currentUser = ref.read(authRepositoryProvider).currentUser;
  return ref
      .watch(confirmationsRepositoryProvider)
      .watchConfirmedMembers(eventId, adminId,
          currentUid: currentUser?.uid ?? '',
          authDisplayName: currentUser?.displayName ?? '');
});

// ─── Repository ───────────────────────────────────────────────────────────────

class ConfirmationsRepository {
  final FirebaseFirestore _db;

  ConfirmationsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _confirmations =>
      _db.collection('confirmations');

  // Nasłuchiwanie statusu jednego użytkownika — dokument identyfikowany parą eventId_userId
  Stream<String?> watchUserConfirmation(String eventId, String userId) {
    return _confirmations
        .doc('${eventId}_$userId')
        .snapshots()
        .map((s) => s.exists ? (s.data()?['status'] as String?) : null);
  }

  // Zliczanie potwierdzeń po stronie serwera — zapytanie filtruje status 'yes'
  Stream<int> watchConfirmedCount(String eventId) {
    return _confirmations
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'yes')
        .snapshots()
        .map((s) => s.docs.length);
  }

  // Pobieranie pełnych profili potwierdzonych uczestników — weryfikacja krzyżowa z kolekcją users
  Stream<List<GroupMember>> watchConfirmedMembers(
    String eventId,
    String adminId, {
    required String currentUid,
    required String authDisplayName,
  }) {
    return _confirmations
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'yes')
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <GroupMember>[];

      // Mapa fallbacków uid → nazwa z dokumentu potwierdzenia, gdy brak profilu users/
      final fallback = <String, String>{
        for (final d in snap.docs)
          (d.data()['userId'] as String? ?? ''):
              (d.data()['userName'] as String? ?? 'Gracz'),
      };
      fallback.remove('');

      final ids = fallback.keys.toList();
      if (ids.isEmpty) return <GroupMember>[];

      // Ograniczenie zapytania whereIn do 30 elementów — limit Firestore
      final usersSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids.take(30).toList())
          .get();

      final profileMap = {for (final d in usersSnap.docs) d.id: d.data()};

      return ids.map((uid) {
        final p = profileMap[uid];
        final rawName = (p?['name'] as String? ?? '').trim();
        final String name;
        if (rawName.isNotEmpty) {
          name = rawName;
        } else if (uid == currentUid && authDisplayName.isNotEmpty) {
          name = authDisplayName;
        } else {
          name = fallback[uid] ?? 'Gracz';
        }
        return GroupMember(
          id: uid,
          name: name,
          level: PlayerLevel.values.firstWhere(
            (l) => l.name == (p?['level'] as String? ?? ''),
            orElse: () => PlayerLevel.recreational,
          ),
          isAdmin: uid == adminId,
        );
      }).toList();
    });
  }

  // Zapis potwierdzenia lub wycofanie go — usunięcie dokumentu = brak potwierdzenia
  Future<void> setConfirmation({
    required String eventId,
    required String userId,
    required String groupId,
    required String status,
    required String userName,
  }) {
    final docRef = _confirmations.doc('${eventId}_$userId');
    if (status.isEmpty) {
      // Wyłączenie potwierdzenia — usunięcie dokumentu oznacza wycofanie zgłoszenia
      return docRef.delete();
    }
    return docRef.set({
      'eventId': eventId,
      'userId': userId,
      'groupId': groupId,
      'status': status,
      'userName': userName,
    });
  }
}
