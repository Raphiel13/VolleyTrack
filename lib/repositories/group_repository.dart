import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(FirebaseFirestore.instance);
});

/// Streams groups where [userId] is in the members array.
/// Usage: `ref.watch(userGroupsProvider('uid-here'))`
final userGroupsProvider =
    StreamProvider.family<List<Group>, String>((ref, userId) {
  return ref.watch(groupRepositoryProvider).watchUserGroups(userId);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class GroupRepository {
  final FirebaseFirestore _db;

  GroupRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Streams groups where [userId] appears in the `members` array,
  /// ordered alphabetically by name.
  Stream<List<Group>> watchUserGroups(String userId) {
    return _groups
        .where('members', arrayContains: userId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new group document. The creator is automatically added to
  /// `members` and set as `adminId`.
  Future<Group> createGroup({
    required String name,
    required String adminId,
    bool isOpen = false,
    String? nextGame,
  }) async {
    final doc = await _groups.add({
      'name': name,
      'adminId': adminId,
      'members': [adminId],
      'isOpen': isOpen,
      'unreadCount': 0,
      if (nextGame != null) 'nextGame': nextGame,
    });

    final snap = await doc.get();
    return _fromDoc(snap);
  }

  /// Adds [userId] to the group's `members` array.
  /// Throws [GroupNotFoundException] if the document does not exist.
  /// Idempotent — safe to call if the user is already a member.
  Future<void> joinGroup(String groupId, String userId) async {
    await _db.runTransaction((tx) async {
      final ref = _groups.doc(groupId);
      final snap = await tx.get(ref);

      if (!snap.exists) throw GroupNotFoundException(groupId);

      tx.update(ref, {
        'members': FieldValue.arrayUnion([userId]),
      });
    });
  }

  /// Removes [userId] from the group's `members` array.
  /// Idempotent — safe to call if the user is not a member.
  Future<void> leaveGroup(String groupId, String userId) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  /// Marks the group as open/closed.
  Future<void> setOpen(String groupId, {required bool isOpen}) {
    return _groups.doc(groupId).update({'isOpen': isOpen});
  }

  /// Updates the nextGame label for a group.
  Future<void> setNextGame(String groupId, String nextGame) {
    return _groups.doc(groupId).update({'nextGame': nextGame});
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  static Group _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;

    // `members` is stored as an array of userId strings; derive count from it.
    final membersList = (d['members'] as List<dynamic>?) ?? [];

    return Group(
      id: doc.id,
      name: d['name'] as String,
      members: membersList.length,
      adminName: d['adminId'] as String? ?? '',
      isOpen: d['isOpen'] as bool? ?? false,
      unreadCount: (d['unreadCount'] as num? ?? 0).toInt(),
      nextGame: d['nextGame'] as String?,
    );
  }
}

// ─── Exceptions ───────────────────────────────────────────────────────────────

class GroupNotFoundException implements Exception {
  final String groupId;
  const GroupNotFoundException(this.groupId);

  @override
  String toString() => 'GroupNotFoundException: group $groupId not found';
}
