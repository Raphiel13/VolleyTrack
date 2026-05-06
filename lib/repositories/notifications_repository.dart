import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(FirebaseFirestore.instance);
});

/// Nasłuchiwanie pierwszego nieprzeczytanego powiadomienia użytkownika.
final firstNotificationProvider =
    StreamProvider.family<GroupNotification?, String>((ref, userId) {
  return ref
      .watch(notificationsRepositoryProvider)
      .watchFirstUnread(userId);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class NotificationsRepository {
  final FirebaseFirestore _db;

  NotificationsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  // Pobieranie tylko pierwszego nieprzeczytanego — limit(1) minimalizuje koszt odczytu
  Stream<GroupNotification?> watchFirstUnread(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final d = doc.data();
      return GroupNotification(
        id: doc.id,
        groupName: d['groupName'] as String? ?? '',
        message: d['message'] as String? ?? '',
      );
    });
  }

  // Oznaczenie powiadomienia jako przeczytanego — aktualizacja pojedynczego pola
  Future<void> markAsRead(String notificationId) {
    return _notifications.doc(notificationId).update({'read': true});
  }

  // Wysłanie powiadomień do wszystkich członków grupy w jednej operacji batch
  Future<void> sendNewEventNotifications({
    required String groupId,
    required String groupName,
    required List<String> memberIds,
  }) async {
    final batch = _db.batch();
    for (final memberId in memberIds) {
      batch.set(
        _notifications.doc(),
        {
          'userId': memberId,
          'groupId': groupId,
          'type': 'new_event',
          'title': 'Nowy termin w grupie',
          'message': 'Nowy termin w grupie $groupName',
          'read': false,
          'createdAt': Timestamp.now(),
        },
      );
    }
    await batch.commit();
  }
}
