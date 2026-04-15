import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(FirebaseFirestore.instance);
});

/// Streams all groups ordered by name.
final groupsProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(groupRepositoryProvider).watchGroups();
});

// ─── Repository ───────────────────────────────────────────────────────────────

class GroupRepository {
  final FirebaseFirestore _db;

  GroupRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// Streams all group documents ordered alphabetically by name.
  Stream<List<Group>> watchGroups() {
    return _groups
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Marks the group as open/closed.
  Future<void> setOpen(String groupId, {required bool isOpen}) {
    return _groups.doc(groupId).update({'isOpen': isOpen});
  }

  /// Updates the nextGame label for a group.
  Future<void> setNextGame(String groupId, String nextGame) {
    return _groups.doc(groupId).update({'nextGame': nextGame});
  }

  static Group _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Group(
      id: doc.id,
      name: d['name'] as String,
      members: (d['members'] as num? ?? 0).toInt(),
      adminName: d['adminName'] as String? ?? '',
      isOpen: d['isOpen'] as bool? ?? false,
      unreadCount: (d['unreadCount'] as num? ?? 0).toInt(),
      nextGame: d['nextGame'] as String?,
    );
  }
}
