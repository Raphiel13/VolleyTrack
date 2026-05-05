import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' show placemarkFromCoordinates;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../repositories/auth_repository.dart';
import '../repositories/group_repository.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

const _kPlacesApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

// ─── Local models ─────────────────────────────────────────────────────────────

class GroupMember {
  final String id;
  final String name;
  final PlayerLevel level;
  final bool isAdmin;

  const GroupMember({
    required this.id,
    required this.name,
    required this.level,
    required this.isAdmin,
  });
}

class GroupEvent {
  final String id;
  final DateTime dateTime;
  final String location;
  final String createdBy;
  final int confirmedCount;
  final List<DateTime> cancelledDates;
  final bool isOpenToPublic;
  final int? maxPlayers;

  const GroupEvent({
    required this.id,
    required this.dateTime,
    required this.location,
    required this.createdBy,
    required this.confirmedCount,
    required this.cancelledDates,
    this.isOpenToPublic = false,
    this.maxPlayers,
  });

  bool get isCancelled => cancelledDates.any((d) =>
      d.year == dateTime.year &&
      d.month == dateTime.month &&
      d.day == dateTime.day &&
      d.hour == dateTime.hour &&
      d.minute == dateTime.minute);
}

class GroupMessage {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final DateTime createdAt;

  const GroupMessage({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Pobieranie dokumentu grupy w celu odczytu identyfikatorów członków i załadowania ich profili.
final _membersProvider =
    StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  // Pobranie danych bieżącego użytkownika jako fallback dla nazwy wyświetlanej
  final currentUser = ref.read(authRepositoryProvider).currentUser;
  final currentUid = currentUser?.uid ?? '';
  final authDisplayName = currentUser?.displayName ?? '';

  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncMap((groupSnap) async {
    if (!groupSnap.exists) return <GroupMember>[];
    final d = groupSnap.data();
    if (d == null) return <GroupMember>[];
    final memberIds =
        List<String>.from((d['members'] as List?) ?? []);
    if (memberIds.isEmpty) return <GroupMember>[];

    final adminId = d['adminId'] as String? ?? '';
    // Ograniczenie zapytania whereIn do 30 elementów — limit Firestore
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId,
            whereIn: memberIds.take(30).toList())
        .get();

    final profileMap = {for (final doc in snap.docs) doc.id: doc.data()};

    // Iteracja po wszystkich memberIds — członkowie bez dokumentu users/ są nadal widoczni
    return memberIds.take(30).map((memberId) {
      final p = profileMap[memberId];
      final rawName = (p?['name'] as String? ?? '').trim();
      final String name;
      if (rawName.isNotEmpty) {
        name = rawName;
      } else if (memberId == currentUid && authDisplayName.isNotEmpty) {
        name = authDisplayName;
      } else {
        name = 'Gracz';
      }
      return GroupMember(
        id: memberId,
        name: name,
        level: PlayerLevel.values.firstWhere(
          (l) => l.name == (p?['level'] as String? ?? ''),
          orElse: () => PlayerLevel.recreational,
        ),
        isAdmin: memberId == adminId,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isAdmin) return -1;
        if (b.isAdmin) return 1;
        return a.name.compareTo(b.name);
      });
  });
});

/// Nasłuchiwanie potwierdzonych uczestników terminu jako pełnych profili [GroupMember].
/// Odczyt potwierdzeń ze statusem 'yes' i weryfikacja krzyżowa z kolekcją 'users'.
/// Fallback na nazwę z dokumentu potwierdzenia gdy profil użytkownika nie istnieje.
final _eventConfirmedProvider =
    StreamProvider.family<List<GroupMember>, (String, String)>(
        (ref, params) {
  final (eventId, adminId) = params;
  if (eventId.isEmpty) return Stream.value([]);

  final currentUser = ref.read(authRepositoryProvider).currentUser;
  final currentUid = currentUser?.uid ?? '';
  final authDisplayName = currentUser?.displayName ?? '';

  return FirebaseFirestore.instance
      .collection('confirmations')
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

    final usersSnap = await FirebaseFirestore.instance
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
});

/// Nasłuchiwanie statusu potwierdzenia bieżącego użytkownika dla danego terminu.
/// ID dokumentu = "${eventId}_${userId}" — zapis w czasie O(1).
final _userConfirmProvider =
    StreamProvider.family<String?, (String, String)>((ref, params) {
  final (eventId, userId) = params;
  if (userId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('confirmations')
      .doc('${eventId}_$userId')
      .snapshots()
      .map((s) => s.exists ? (s.data()?['status'] as String?) : null);
});

/// Nasłuchiwanie liczby potwierdzeń dla terminu ze statusem 'yes'.
final _confirmedCountProvider =
    StreamProvider.family<int, String>((ref, eventId) {
  return FirebaseFirestore.instance
      .collection('confirmations')
      .where('eventId', isEqualTo: eventId)
      .where('status', isEqualTo: 'yes')
      .snapshots()
      .map((s) => s.docs.length);
});

/// Nasłuchiwanie nadchodzących terminów grupy posortowanych po dateTime.
/// Odfiltrowanie terminów z anulowanymi datami po stronie klienta.
final _groupEventsProvider =
    StreamProvider.family<List<GroupEvent>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('events')
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
});

/// Streams group messages newest-first (reversed in ListView).
final _groupMessagesProvider =
    StreamProvider.family<List<GroupMessage>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('messages')
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
});

// ─── GroupDetailScreen ────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // Generowanie nowego kodu zaproszenia i wyświetlanie go z opcją kopiowania do schowka
  Future<void> _showInviteSheet(BuildContext context) async {
    final t = AppTokens.of(context);
    final code = await ref
        .read(groupRepositoryProvider)
        .generateInviteCode(widget.group.id);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: t.separator, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Kod zaproszenia',
                style: AppTheme.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: t.label)),
            const SizedBox(height: 6),
            Text('Podziel się kodem, aby zaprosić do grupy',
                style: AppTheme.inter(fontSize: 14, color: t.label2)),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code,
                      style: AppTheme.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blue,
                          letterSpacing: 10)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Skopiowano kod',
                            style: AppTheme.inter()),
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.copy,
                          size: 20, color: AppColors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Kod jest jednorazowy i wygasa po użyciu',
                style: AppTheme.inter(fontSize: 12, color: t.label3)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final isAdmin = uid == widget.group.adminName;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.blue,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(
            widget.group.name,
            style: AppTheme.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: t.label),
          ),
          Text(
            '${widget.group.members} członków',
            style: AppTheme.inter(fontSize: 12, color: t.label2),
          ),
        ]),
        actions: isAdmin
            ? [
                TextButton(
                  onPressed: () => _showInviteSheet(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.person_badge_plus,
                          size: 16, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Text('Zaproś',
                          style: AppTheme.inter(
                              fontSize: 14, color: AppColors.blue)),
                    ],
                  ),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.blue,
          unselectedLabelColor: t.label2,
          indicatorColor: AppColors.blue,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              AppTheme.inter(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTheme.inter(fontSize: 14),
          tabs: const [
            Tab(text: 'Skład'),
            Tab(text: 'Terminarz'),
            Tab(text: 'Czat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RosterTab(group: widget.group),
          _ScheduleTab(group: widget.group),
          _ChatTab(group: widget.group),
        ],
      ),
    );
  }
}

// ─── Tab 1: Skład ─────────────────────────────────────────────────────────────

/// Paleta kolorów awatarów — deterministyczna na podstawie hasha uid użytkownika
const _kAvatarColors = <Color>[
  AppColors.blue,
  AppColors.teal,
  AppColors.green,
  AppColors.orange,
  AppColors.purple,
  Color(0xFF5856D6), // indygo
  Color(0xFFFF2D55), // różowy
];

Color _avatarColor(String uid) =>
    _kAvatarColors[uid.hashCode.abs() % _kAvatarColors.length];

class _RosterTab extends ConsumerWidget {
  final Group group;
  const _RosterTab({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final isAdmin = uid.isNotEmpty && uid == group.adminName;

    // Najbliższy termin — pierwszy element posortowanej listy
    final nextEvent =
        ref.watch(_groupEventsProvider(group.id)).valueOrNull?.firstOrNull;

    // Potwierdzone osoby dla tego terminu — pusty strumień gdy brak terminu
    final confirmedAsync = ref.watch(
        _eventConfirmedProvider((nextEvent?.id ?? '', group.adminName)));

    // Wszyscy członkowie grupy — potrzebni do sekcji niepotwierdzonych admina
    final membersAsync = ref.watch(_membersProvider(group.id));

    final items = <Widget>[];

    // ── Section: Potwierdzili ────────────────────────────────────────────
    if (nextEvent != null) {
      const months = [
        '', 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
        'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
      ];
      final dt = nextEvent.dateTime;
      final dateLabel =
          '${dt.day} ${months[dt.month]} · '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';

      final confirmed = confirmedAsync.valueOrNull ?? [];
      items.add(SectionLabel('Potwierdzili — $dateLabel (${confirmed.length})'));

      if (confirmedAsync.isLoading) {
        items.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(
                color: AppColors.blue, strokeWidth: 2.5),
          ),
        ));
      } else if (confirmed.isEmpty) {
        items.add(IosCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('Nikt jeszcze nie potwierdził',
                  style: AppTheme.inter(fontSize: 14, color: t.label3)),
            ),
          ),
        ));
      } else {
        items.add(IosCard(
          child: Column(
            children: confirmed.asMap().entries.map((e) {
              final m = e.value;
              final isLast = e.key == confirmed.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(children: [
                    UserAvatar(
                        name: m.name,
                        size: 38,
                        color: _avatarColor(m.id)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(m.name,
                                  style: AppTheme.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: t.label),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (m.isAdmin) ...[
                              const SizedBox(width: 6),
                              const ChipBadge('Admin',
                                  variant: ChipVariant.blue),
                            ],
                          ]),
                          const SizedBox(height: 2),
                          Text(m.level.label,
                              style: AppTheme.inter(
                                  fontSize: 12, color: t.label2)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    LevelDots(level: m.level),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.checkmark_circle_fill,
                        size: 18, color: AppColors.green),
                  ]),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 64),
                    child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: t.separator),
                  ),
              ]);
            }).toList(),
          ),
        ));
      }

      // ── Section: Bez odpowiedzi (admin only) ──────────────────────────
      if (isAdmin) {
        final confirmedIds =
            confirmed.map((c) => c.id).toSet();
        final members = membersAsync.valueOrNull ?? [];
        final unconfirmed =
            members.where((m) => !confirmedIds.contains(m.id)).toList();

        if (unconfirmed.isNotEmpty) {
          items.add(const SizedBox(height: 8));
          items.add(
              SectionLabel('Bez odpowiedzi (${unconfirmed.length})'));
          items.add(IosCard(
            child: Column(
              children: unconfirmed.asMap().entries.map((e) {
                final m = e.value;
                final isLast = e.key == unconfirmed.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(children: [
                      UserAvatar(
                          name: m.name,
                          size: 38,
                          color: _avatarColor(m.id)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.name,
                            style: AppTheme.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.label)),
                      ),
                      Icon(CupertinoIcons.clock,
                          size: 16, color: t.label3),
                    ]),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 64),
                      child: Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: t.separator),
                    ),
                ]);
              }).toList(),
            ),
          ));
        }
      }
    } else {
      // Brak nadchodzących terminów — wyświetlenie pełnej listy członków
      final members = membersAsync.valueOrNull;
      if (members == null) {
        items.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(
                color: AppColors.blue, strokeWidth: 2.5),
          ),
        ));
      } else if (members.isEmpty) {
        items.add(Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.person_2, size: 44, color: t.label4),
              const SizedBox(height: 12),
              Text('Brak członków',
                  style: AppTheme.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.label2)),
            ],
          ),
        ));
      } else {
        items.add(SectionLabel('${members.length} członków'));
        items.add(IosCard(
          child: Column(
            children: members.asMap().entries.map((e) {
              final m = e.value;
              final isLast = e.key == members.length - 1;
              return _MemberRow(
                member: m,
                avatarColor: _avatarColor(m.id),
                showTopRadius: e.key == 0,
                showBottomRadius: isLast,
                showSeparator: !isLast,
              );
            }).toList(),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: items,
    );
  }
}

class _MemberRow extends StatelessWidget {
  final GroupMember member;
  final Color avatarColor;
  final bool showTopRadius;
  final bool showBottomRadius;
  final bool showSeparator;

  const _MemberRow({
    required this.member,
    required this.avatarColor,
    required this.showTopRadius,
    required this.showBottomRadius,
    required this.showSeparator,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.vertical(
          top: showTopRadius ? const Radius.circular(14) : Radius.zero,
          bottom: showBottomRadius ? const Radius.circular(14) : Radius.zero,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // ── Avatar ────────────────────────────────────────────
                UserAvatar(
                  name: member.name,
                  size: 42,
                  color: avatarColor,
                ),
                const SizedBox(width: 12),
                // ── Name + level ──────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: AppTheme.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.label),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.isAdmin) ...[
                          const SizedBox(width: 6),
                          const ChipBadge('Admin',
                              variant: ChipVariant.blue),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        member.level.label,
                        style:
                            AppTheme.inter(fontSize: 13, color: t.label2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Level dots ────────────────────────────────────────
                LevelDots(level: member.level),
              ],
            ),
          ),
          if (showSeparator)
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 0.5, thickness: 0.5, color: t.separator),
            ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Terminarz ─────────────────────────────────────────────────────────

class _ScheduleTab extends ConsumerWidget {
  final Group group;
  const _ScheduleTab({required this.group});

  void _showAddSheet(BuildContext context, String uid, String organizerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(
        groupId: group.id,
        uid: uid,
        groupName: group.name,
        organizerName: organizerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final currentUser = ref.watch(authRepositoryProvider).currentUser;
    final uid = currentUser?.uid ?? '';
    final organizerName = currentUser?.displayName ?? '';
    // group.adminName przechowuje adminId — mapowanie w GroupRepository._fromDoc
    final isAdmin = uid.isNotEmpty && uid == group.adminName;
    final eventsAsync = ref.watch(_groupEventsProvider(group.id));

    return Stack(
      children: [
        eventsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.blue, strokeWidth: 2.5),
          ),
          error: (_, __) => Center(
            child: Text('Nie udało się załadować terminarza',
                style: AppTheme.inter(fontSize: 14, color: t.label3)),
          ),
          data: (events) {
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 44, color: t.label4),
                    const SizedBox(height: 12),
                    Text('Brak zaplanowanych terminów',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.label2)),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? 'Kliknij + aby dodać pierwszy termin'
                          : 'Admin jeszcze nie dodał terminów',
                      style:
                          AppTheme.inter(fontSize: 13, color: t.label3),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, isAdmin ? 96 : 32),
              itemCount: events.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EventTile(
                  event: events[i],
                  isAdmin: isAdmin,
                  uid: uid,
                  groupId: group.id,
                ),
              ),
            );
          },
        ),

        // ── Admin FAB ─────────────────────────────────────────────────────
        if (isAdmin)
          Positioned(
            right: 20,
            bottom: 24,
            child: GestureDetector(
              onTap: () => _showAddSheet(context, uid, organizerName),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Tab 3: Czat ──────────────────────────────────────────────────────────────

class _ChatTab extends ConsumerStatefulWidget {
  final Group group;
  const _ChatTab({required this.group});

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final authUser = ref.read(authRepositoryProvider).currentUser;
    final uid = authUser?.uid ?? '';

    // Rozwiązanie nazwy wyświetlanej: users/{uid}.name → Auth displayName → 'Gracz'
    String userName = authUser?.displayName ?? '';
    if (uid.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (doc.data()?['name'] as String? ?? '').trim();
      if (name.isNotEmpty) userName = name;
    }
    if (userName.isEmpty) userName = 'Gracz';

    await FirebaseFirestore.instance.collection('messages').add({
      'text': text,
      'userId': uid,
      'userName': userName,
      'groupId': widget.group.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final messagesAsync =
        ref.watch(_groupMessagesProvider(widget.group.id));

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.blue, strokeWidth: 2.5),
            ),
            error: (_, __) => Center(
              child: Text('Nie udało się załadować czatu',
                  style: AppTheme.inter(fontSize: 14, color: t.label3)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text('Brak wiadomości. Napisz coś!',
                      style: AppTheme.inter(fontSize: 14, color: t.label3)),
                );
              }
              // Najnowsze wiadomości z Firestore + reverse: true = najnowsze na dole listy
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, i) => _ChatBubble(
                  msg: messages[i],
                  isMe: messages[i].userId == uid,
                ),
              );
            },
          ),
        ),

        // ── Input bar ─────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                10,
          ),
          decoration: BoxDecoration(
            color: t.glassBg,
            border: Border(top: BorderSide(color: t.separator, width: 0.5)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(hintText: 'Wiadomość'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.blue),
                child: const Icon(Icons.arrow_upward,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _EventTile extends ConsumerWidget {
  final GroupEvent event;
  final bool isAdmin;
  final String uid;
  final String groupId;

  const _EventTile({
    required this.event,
    required this.uid,
    required this.groupId,
    this.isAdmin = false,
  });

  Future<void> _setConfirmation(WidgetRef ref, String status) async {
    final docRef = FirebaseFirestore.instance
        .collection('confirmations')
        .doc('${event.id}_$uid');

    if (status.isEmpty) {
      // Wyłączenie potwierdzenia — usunięcie dokumentu oznacza wycofanie zgłoszenia
      await docRef.delete();
      return;
    }

    // Rozwiązanie nazwy wyświetlanej: users/{uid}.name → Auth displayName → 'Gracz'
    String userName =
        ref.read(authRepositoryProvider).currentUser?.displayName ?? '';
    if (uid.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (doc.data()?['name'] as String? ?? '').trim();
      if (name.isNotEmpty) userName = name;
    }
    if (userName.isEmpty) userName = 'Gracz';

    await docRef.set({
      'eventId': event.id,
      'userId': uid,
      'groupId': groupId,
      'status': status,
      'userName': userName,
    });
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dlgCtx) => CupertinoAlertDialog(
        title: const Text('Anulować termin?'),
        content: const Text('Termin zostanie oznaczony jako odwołany.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Anuluj termin'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Wróć'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance
        .collection('events')
        .doc(event.id)
        .update({
      'cancelledDates':
          FieldValue.arrayUnion([Timestamp.fromDate(event.dateTime)]),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);

    final myStatus =
        ref.watch(_userConfirmProvider((event.id, uid))).valueOrNull;
    final confirmedCount =
        ref.watch(_confirmedCountProvider(event.id)).valueOrNull ??
            event.confirmedCount;

    const weekdays = ['', 'Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    const months = [
      '', 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
      'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
    ];
    final dt = event.dateTime;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return IosCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              // Kafelek daty
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(weekdays[dt.weekday],
                        style: AppTheme.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue)),
                    Text('${dt.day}',
                        style: AppTheme.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                            letterSpacing: -0.5)),
                    Text(months[dt.month],
                        style: AppTheme.inter(
                            fontSize: 11, color: AppColors.blue)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Szczegóły terminu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time,
                        style: AppTheme.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.label)),
                    const SizedBox(height: 3),
                    Text(event.location,
                        style:
                            AppTheme.inter(fontSize: 13, color: t.label2)),
                  ],
                ),
              ),
              // Liczba potwierdzeń
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$confirmedCount',
                      style: AppTheme.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green)),
                  Text('potw.',
                      style:
                          AppTheme.inter(fontSize: 11, color: t.label3)),
                ],
              ),
              // Akcje admina
              if (isAdmin) ...[
                const SizedBox(width: 8),
                // Przełączenie statusu publicznego terminu
                GestureDetector(
                  onTap: () => FirebaseFirestore.instance
                      .collection('events')
                      .doc(event.id)
                      .update({
                    'isOpenToPublic': !event.isOpenToPublic,
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: event.isOpenToPublic
                          ? AppColors.green.withValues(alpha: 0.12)
                          : t.bg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: event.isOpenToPublic
                            ? AppColors.green
                            : t.separator,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      event.isOpenToPublic ? 'Otwarta' : 'Zamknij',
                      style: AppTheme.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: event.isOpenToPublic
                            ? AppColors.green
                            : t.label3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Anulowanie terminu
                GestureDetector(
                  onTap: () => _cancel(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.xmark,
                        size: 14, color: AppColors.red),
                  ),
                ),
              ] else if (event.isOpenToPublic) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Otwarta',
                    style: AppTheme.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 0.5, thickness: 0.5, color: t.separator),
          const SizedBox(height: 10),

          // ── Confirmation buttons ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ConfirmBtn(
                  label: '✓  Będę',
                  active: myStatus == 'yes',
                  activeColor: AppColors.green,
                  onTap: uid.isEmpty
                      ? null
                      : () => _setConfirmation(
                          ref, myStatus == 'yes' ? '' : 'yes'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConfirmBtn(
                  label: '✕  Nie mogę',
                  active: myStatus == 'no',
                  activeColor: AppColors.red,
                  onTap: uid.isEmpty
                      ? null
                      : () => _setConfirmation(
                          ref, myStatus == 'no' ? '' : 'no'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ConfirmBtn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : t.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeColor : t.separator,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.inter(
              fontSize: 13,
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.w500,
              color: active ? activeColor : t.label2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add Event Sheet ──────────────────────────────────────────────────────────

class _AddEventSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String uid;
  final String groupName;
  final String organizerName;
  const _AddEventSheet({
    required this.groupId,
    required this.uid,
    required this.groupName,
    required this.organizerName,
  });

  @override
  ConsumerState<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<_AddEventSheet> {
  final _locationCtrl = TextEditingController();
  final _maxPlayersCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate = _roundedNow();
  bool _isOpenToPublic = false;
  bool _loading = false;
  double? _latitude;
  double? _longitude;

  static DateTime _roundedNow() {
    final base = DateTime.now().add(const Duration(days: 1));
    final minute = (base.minute ~/ 5) * 5;
    return DateTime(base.year, base.month, base.day, base.hour, minute);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker(BuildContext context) async {
    final initialLoc = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _LocationPickerScreen(initialLocation: initialLoc),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result['lat'] as double;
        _longitude = result['lng'] as double;
        _locationCtrl.text = result['address'] as String;
      });
    }
  }

  void _pickDateTime(BuildContext context) {
    final t = AppTokens.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      // Użycie kontekstu popupu do Navigator.pop — kontekst zewnętrzny może wygasnąć
      // gdy picker jest widoczny, co powoduje błąd null w Navigator.of(context)
      builder: (popupCtx) => Container(
        height: 300,
        color: t.bg,
        child: Column(
          children: [
            // ── Toolbar ──────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg2,
                border: Border(
                    bottom: BorderSide(color: t.separator, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(popupCtx),
                    child: Text('Anuluj',
                        style: AppTheme.inter(
                            fontSize: 16, color: t.label2)),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(popupCtx),
                    child: Text('Gotowe',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue)),
                  ),
                ],
              ),
            ),
            // ── Picker ───────────────────────────────────────────────────
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: _selectedDate,
                minimumDate: DateTime.now(),
                use24hFormat: true,
                minuteInterval: 5,
                onDateTimeChanged: (dt) =>
                    setState(() => _selectedDate = dt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Podaj lokalizację', style: AppTheme.inter()),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Wybierz lokalizację z listy sugestii',
            style: AppTheme.inter()),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _loading = true);

    try {
      // Tworzenie terminu, aktualizacja nextGame w grupie i wysyłanie powiadomień do członków
      // 1. Create the event document.
      await FirebaseFirestore.instance.collection('events').add({
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'dateTime': Timestamp.fromDate(_selectedDate),
        'location': _locationCtrl.text.trim(),
        'createdBy': widget.uid,
        'createdByName': widget.organizerName,
        'confirmedIds': [],
        'cancelledDates': [],
        'isOpenToPublic': _isOpenToPublic,
        'maxPlayers':
            _isOpenToPublic ? int.tryParse(_maxPlayersCtrl.text) ?? 10 : null,
        'spotsTaken': 0,
        'latitude': _latitude,
        'longitude': _longitude,
        'price': double.tryParse(
            _priceCtrl.text.trim().replaceAll(',', '.')),
      });

      // 2. Update nextGame label on the group document.
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'nextGame': DateFormat('dd.MM.yyyy HH:mm').format(_selectedDate),
      });

      // 3. Fetch group to get member list + name for notifications.
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      final gd = groupDoc.data();
      if (gd != null) {
        final memberIds =
            List<String>.from((gd['members'] as List?) ?? []);
        final groupName = gd['name'] as String? ?? '';
        final batch = FirebaseFirestore.instance.batch();
        for (final memberId in memberIds) {
          batch.set(
            FirebaseFirestore.instance.collection('notifications').doc(),
            {
              'userId': memberId,
              'groupId': widget.groupId,
              'type': 'new_event',
              'message': 'Nowy termin w grupie $groupName',
              'read': false,
              'createdAt': Timestamp.now(),
            },
          );
        }
        await batch.commit();
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się dodać terminu',
                style: AppTheme.inter()),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    const weekdays = ['', 'Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    const months = [
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
      'gru'
    ];
    final dt = _selectedDate;
    final dateLabel =
        '${weekdays[dt.weekday]}, ${dt.day} ${months[dt.month]} · '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Nowy termin',
                style: AppTheme.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.label),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // ── Date & time picker ───────────────────────────────────────
            Text('Data i godzina',
                style: AppTheme.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.label2)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _pickDateTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(CupertinoIcons.calendar,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(dateLabel,
                        style: AppTheme.inter(
                            fontSize: 15, color: t.label)),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14, color: t.label3),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ── Location field ───────────────────────────────────────────
            Text('Lokalizacja',
                style: AppTheme.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.label2)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openLocationPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: _latitude != null
                      ? Border.all(
                          color: AppColors.blue, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _latitude != null
                          ? CupertinoIcons.location_fill
                          : CupertinoIcons.location,
                      size: 16,
                      color: _latitude != null
                          ? AppColors.blue
                          : t.label3,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationCtrl.text.isNotEmpty
                            ? _locationCtrl.text
                            : 'Zaznacz na mapie',
                        style: AppTheme.inter(
                          fontSize: 15,
                          color: _locationCtrl.text.isNotEmpty
                              ? t.label
                              : t.label4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 14, color: t.label3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Open to public ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Otwarta dla osób spoza grupy',
                            style: AppTheme.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.label)),
                        const SizedBox(height: 2),
                        Text('Gra pojawi się na mapie publicznej',
                            style: AppTheme.inter(
                                fontSize: 12, color: t.label2)),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _isOpenToPublic,
                    activeTrackColor: AppColors.green,
                    onChanged: (v) =>
                        setState(() => _isOpenToPublic = v),
                  ),
                ],
              ),
            ),
            if (_isOpenToPublic) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _maxPlayersCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Maks. liczba graczy (domyślnie 10)',
                  hintStyle: AppTheme.inter(color: t.label4),
                  filled: true,
                  fillColor: t.bg2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.blue, width: 1.5),
                  ),
                  prefixIcon: const Icon(CupertinoIcons.person_2,
                      size: 16, color: AppColors.blue),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                style: AppTheme.inter(fontSize: 15, color: t.label),
              ),
            ],
            const SizedBox(height: 10),

            // ── Price ─────────────────────────────────────────────────────
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Cena (opcjonalnie, np. 15.00)',
                hintStyle: AppTheme.inter(color: t.label4),
                filled: true,
                fillColor: t.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.blue, width: 1.5),
                ),
                prefixIcon: const Icon(CupertinoIcons.money_dollar_circle,
                    size: 16, color: AppColors.blue),
                suffixText: 'zł',
                suffixStyle: AppTheme.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blue),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: AppTheme.inter(fontSize: 15, color: t.label),
            ),
            const SizedBox(height: 28),

            // ── Submit ───────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  disabledBackgroundColor:
                      AppColors.blue.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text('Dodaj termin',
                        style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final GroupMessage msg;
  final bool isMe;
  const _ChatBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final time =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
                name: msg.userName,
                size: 28,
                color: _avatarColor(msg.userId)),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(msg.userName,
                      style: AppTheme.inter(
                          fontSize: 11,
                          color: t.label3,
                          fontWeight: FontWeight.w500)),
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.blue : t.bg2,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Text(msg.text,
                    style: AppTheme.inter(
                        fontSize: 15,
                        color: isMe ? Colors.white : t.label,
                        height: 1.4)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(time,
                    style: AppTheme.inter(fontSize: 11, color: t.label3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Location Picker Screen ───────────────────────────────────────────────────

class _LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const _LocationPickerScreen({this.initialLocation});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  static const _kPoland = LatLng(52.0, 19.0);

  GoogleMapController? _mapCtrl;
  late LatLng _center;
  String _address = '';
  bool _geocoding = false;
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation ?? _kPoland;
    _reverseGeocode(_center);
    if (widget.initialLocation == null) _tryUserLocation();
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _tryUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = loc);
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(loc, 14));
      _reverseGeocode(loc);
    } catch (_) {}
  }

  // Odwrotne geokodowanie współrzędnych na adres — aktualizacja przy każdym zatrzymaniu kamery
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() {
      _geocoding = true;
      _address = '';
    });
    try {
      final marks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = <String>[
          if (p.street?.isNotEmpty == true) p.street!,
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.locality?.isNotEmpty == true) p.locality!,
        ];
        setState(() => _address =
            parts.isNotEmpty ? parts.join(', ') : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.blue,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Wybierz lokalizację',
          style: AppTheme.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.label),
        ),
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: t.separator),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: widget.initialLocation != null ? 15.0 : 6.0,
                  ),
                  onMapCreated: (c) => _mapCtrl = c,
                  onCameraMove: (pos) => _center = pos.target,
                  onCameraIdle: () {
                    _geocodeTimer?.cancel();
                    _geocodeTimer = Timer(
                      const Duration(milliseconds: 500),
                      () => _reverseGeocode(_center),
                    );
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  gestureRecognizers: const {},
                ),
                // Niebieski pin jako nakładka — nieruchomy względem mapy
                Center(
                  child: Padding(
                    // Przesunięcie w górę o połowę wysokości pinu — czubek wskazuje środek mapy
                    padding: const EdgeInsets.only(bottom: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x59007AFF),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_pin,
                              color: Colors.white, size: 22),
                        ),
                        // Nóżka pinu
                        Container(width: 3, height: 12, color: AppColors.blue),
                        Container(
                          width: 8,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Zoom controls
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(children: [
                    _ZoomButton(
                        label: '+',
                        onTap: () =>
                            _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
                    const SizedBox(height: 1),
                    _ZoomButton(
                        label: '−',
                        onTap: () =>
                            _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
                  ]),
                ),
              ],
            ),
          ),
          // Adres i przycisk potwierdzenia
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: t.bg,
              border:
                  Border(top: BorderSide(color: t.separator, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 36,
                  child: _geocoding
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.blue, strokeWidth: 2.5),
                          ),
                        )
                      : Row(children: [
                          const Icon(CupertinoIcons.location_fill,
                              size: 16, color: AppColors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _address.isNotEmpty
                                  ? _address
                                  : 'Przesuń mapę, aby wybrać miejsce',
                              style: AppTheme.inter(
                                fontSize: 14,
                                color: _address.isNotEmpty
                                    ? t.label
                                    : t.label3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_address.isEmpty || _geocoding)
                        ? null
                        : () => Navigator.pop(context, {
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'address': _address,
                            }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      disabledBackgroundColor:
                          AppColors.blue.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Potwierdź lokalizację',
                      style: AppTheme.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ZoomButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }
}
