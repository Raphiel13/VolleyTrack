import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(FirebaseFirestore.instance);
});

// Nasłuchiwanie grup danego użytkownika jako reaktywny strumień
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

  // Filtrowanie po tablicy members — Firestore obsługuje arrayContains jako pojedynczy indeks
  Stream<List<Group>> watchUserGroups(String userId) {
    return _groups
        .where('members', arrayContains: userId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  // Założenie grupy i automatyczne dodanie twórcy jako pierwszego członka i admina
  Future<Group> createGroup({
    required String name,
    required String adminId,
    bool isOpen = false,
    String? nextGame,
    String? icon,
  }) async {
    final doc = await _groups.add({
      'name': name,
      'adminId': adminId,
      'members': [adminId],
      'isOpen': isOpen,
      'unreadCount': 0,
      if (nextGame != null) 'nextGame': nextGame,
      if (icon != null) 'icon': icon,
    });

    final snap = await doc.get();
    return _fromDoc(snap);
  }

  // Dołączenie do grupy w transakcji — sprawdzenie istnienia dokumentu przed modyfikacją
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

  // Usunięcie z listy members — arrayRemove jest idempotentne, nie rzuca błędu gdy brak elementu
  Future<void> leaveGroup(String groupId, String userId) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> setOpen(String groupId, {required bool isOpen}) {
    return _groups.doc(groupId).update({'isOpen': isOpen});
  }

  Future<void> setNextGame(String groupId, String nextGame) {
    return _groups.doc(groupId).update({'nextGame': nextGame});
  }

  // ── Invite codes ───────────────────────────────────────────────────────────

  static const _kChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  // Użycie kryptograficznie bezpiecznego generatora — unikanie przewidywalności kodów
  static final _rng = Random.secure();

  static String _randomCode() => List.generate(
        6, (_) => _kChars[_rng.nextInt(_kChars.length)]).join();

  // Wygenerowanie nowego kodu i nadpisanie poprzedniego — kod jest jednorazowy z założenia
  Future<String> generateInviteCode(String groupId) async {
    final code = _randomCode();
    await _groups.doc(groupId).update({'inviteCode': code});
    return code;
  }

  // Wyszukanie grupy po kodzie — limit(1) ogranicza koszt odczytu do minimum
  Future<Group?> findGroupByInviteCode(String code) async {
    final snap = await _groups
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _fromDoc(snap.docs.first);
  }

  // Dołączenie przez kod — połączenie wyszukiwania i zapisu w dwóch krokach
  Future<void> joinGroupByCode(String code, String userId) async {
    final group = await findGroupByInviteCode(code);
    if (group == null) throw GroupNotFoundException(code);
    await joinGroup(group.id, userId);
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  static Group _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;

    // Liczba członków wywnioskowana z długości tablicy — nie przechowywana osobno
    final membersList = (d['members'] as List<dynamic>?) ?? [];

    return Group(
      id: doc.id,
      name: d['name'] as String,
      members: membersList.length,
      adminName: d['adminId'] as String? ?? '',
      isOpen: d['isOpen'] as bool? ?? false,
      unreadCount: (d['unreadCount'] as num? ?? 0).toInt(),
      nextGame: d['nextGame'] as String?,
      icon: d['icon'] as String?,
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
