import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(FirebaseFirestore.instance);
});

/// Nasłuchiwanie wiadomości czatu grupy posortowanych malejąco po dacie.
final groupMessagesProvider =
    StreamProvider.family<List<GroupMessage>, String>((ref, groupId) {
  return ref.watch(messagesRepositoryProvider).watchGroupMessages(groupId);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class MessagesRepository {
  final FirebaseFirestore _db;

  MessagesRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  // Pobieranie 50 ostatnich wiadomości grupy — serwer sortuje malejąco, ListView odwraca
  Stream<List<GroupMessage>> watchGroupMessages(String groupId) {
    return _messages
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return GroupMessage(
                id: doc.id,
                text: d['text'] as String? ?? '',
                userId: d['userId'] as String? ?? '',
                userName: d['userName'] as String? ?? '',
                createdAt:
                    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              );
            }).toList());
  }

  // Wysłanie wiadomości czatu — serverTimestamp zapewnia spójną kolejność bez zegara klienta
  Future<void> sendMessage({
    required String groupId,
    required String userId,
    required String userName,
    required String text,
  }) {
    return _messages.add({
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
