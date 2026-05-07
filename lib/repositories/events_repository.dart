import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(FirebaseFirestore.instance);
});

/// Nasłuchiwanie nadchodzących terminów grupy posortowanych po dateTime.
final groupEventsProvider =
    StreamProvider.family<List<GroupEvent>, String>((ref, groupId) {
  return ref.watch(eventsRepositoryProvider).watchGroupEvents(groupId);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class EventsRepository {
  final FirebaseFirestore _db;

  EventsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  // Odfiltrowanie anulowanych terminów po stronie klienta — brak indeksu złożonego dla cancelledDates
  Stream<List<GroupEvent>> watchGroupEvents(String groupId) {
    return _events
        .where('groupId', isEqualTo: groupId)
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              final d = doc.data();
              final confirmed =
                  List.from((d['confirmedIds'] as List?) ?? []);
              final cancelled = ((d['cancelledDates'] as List?) ?? [])
                  .whereType<Timestamp>()
                  .map((t) => t.toDate())
                  .toList();
              return GroupEvent(
                id: doc.id,
                dateTime: (d['dateTime'] as Timestamp).toDate(),
                location: d['location'] as String? ?? '',
                createdBy: d['createdBy'] as String? ?? '',
                confirmedCount: confirmed.length,
                cancelledDates: cancelled,
                isOpenToPublic: d['isOpenToPublic'] as bool? ?? false,
                maxPlayers: (d['maxPlayers'] as num?)?.toInt(),
              );
            })
            .where((e) => !e.isCancelled)
            .toList());
  }

  // Tworzenie terminu — wszystkie pola zapisywane atomowo w jednym dokumencie.
  // Pole playerIds inicjalizowane jako pusta tablica obsługuje zapisy osób
  // spoza grupy na publiczne terminy. Członkowie grupy korzystają z osobnego
  // mechanizmu confirmedIds dostępnego przez ConfirmationsRepository.
  Future<DocumentReference<Map<String, dynamic>>> createEvent({
    required String groupId,
    required String groupName,
    required DateTime dateTime,
    required String location,
    required String createdBy,
    required String createdByName,
    required bool isOpenToPublic,
    int? maxPlayers,
    double? latitude,
    double? longitude,
    double? price,
  }) {
    return _events.add({
      'groupId': groupId,
      'groupName': groupName,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'confirmedIds': [],
      'cancelledDates': [],
      'playerIds': <String>[],
      'isOpenToPublic': isOpenToPublic,
      'maxPlayers': isOpenToPublic ? maxPlayers : null,
      'latitude': latitude,
      'longitude': longitude,
      'price': price,
    });
  }

  // Zapisanie zewnętrznego użytkownika na publiczny termin —
  // operacja transakcyjna sprawdzająca limit miejsc i unikająca duplikatów
  Future<void> joinEvent(String eventId, String userId) async {
    await _db.runTransaction((tx) async {
      final ref = _events.doc(eventId);
      final snap = await tx.get(ref);

      if (!snap.exists) throw EventNotFoundException(eventId);

      final data = snap.data()!;
      final playerIds = List<String>.from(data['playerIds'] as List? ?? []);
      final maxPlayers = (data['maxPlayers'] as num?)?.toInt();

      // Limit miejsc obowiązuje tylko gdy organizator go ustawił
      if (maxPlayers != null && playerIds.length >= maxPlayers) {
        throw EventFullException(eventId);
      }
      if (playerIds.contains(userId)) return; // idempotentne

      tx.update(ref, {
        'playerIds': FieldValue.arrayUnion([userId]),
      });
    });
  }

  // Wypisanie zewnętrznego użytkownika z publicznego terminu
  Future<void> leaveEvent(String eventId, String userId) async {
    await _db.runTransaction((tx) async {
      final ref = _events.doc(eventId);
      final snap = await tx.get(ref);

      if (!snap.exists) throw EventNotFoundException(eventId);

      final data = snap.data()!;
      final playerIds = List<String>.from(data['playerIds'] as List? ?? []);
      if (!playerIds.contains(userId)) return; // idempotentne

      tx.update(ref, {
        'playerIds': FieldValue.arrayRemove([userId]),
      });
    });
  }

  // Anulowanie terminu — dodanie daty do tablicy cancelledDates zamiast usuwania dokumentu
  Future<void> cancelEventDate(String eventId, DateTime dateTime) {
    return _events.doc(eventId).update({
      'cancelledDates':
          FieldValue.arrayUnion([Timestamp.fromDate(dateTime)]),
    });
  }

  // Przełączenie widoczności terminu dla osób spoza grupy
  Future<void> setOpenToPublic(String eventId, {required bool isOpen}) {
    return _events.doc(eventId).update({'isOpenToPublic': isOpen});
  }
}

// ─── Exceptions ───────────────────────────────────────────────────────────────

class EventNotFoundException implements Exception {
  final String eventId;
  const EventNotFoundException(this.eventId);

  @override
  String toString() => 'EventNotFoundException: event $eventId not found';
}

class EventFullException implements Exception {
  final String eventId;
  const EventFullException(this.eventId);

  @override
  String toString() => 'EventFullException: event $eventId has no spots left';
}