import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

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

enum ConfirmationStatus { going, notGoing, noReply }

class GameConfirmation {
  final String userId;
  final ConfirmationStatus status;

  const GameConfirmation({required this.userId, required this.status});
}

class GroupEvent {
  final String id;
  final DateTime dateTime;
  final String location;
  final String createdBy;
  final int confirmedCount;
  final List<DateTime> cancelledDates;

  const GroupEvent({
    required this.id,
    required this.dateTime,
    required this.location,
    required this.createdBy,
    required this.confirmedCount,
    required this.cancelledDates,
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

/// Fetches the group document to get member IDs, then loads user profiles.
final _membersProvider =
    StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncMap((groupSnap) async {
    if (!groupSnap.exists) return <GroupMember>[];
    final d = groupSnap.data()!;
    final memberIds =
        List<String>.from((d['members'] as List?) ?? []);
    if (memberIds.isEmpty) return <GroupMember>[];

    final adminId = d['adminId'] as String? ?? '';
    // Firestore whereIn limit: 30 items
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId,
            whereIn: memberIds.take(30).toList())
        .get();

    return snap.docs.map((doc) {
      final u = doc.data();
      return GroupMember(
        id: doc.id,
        name: u['name'] as String? ?? '',
        level: PlayerLevel.values.firstWhere(
          (l) => l.name == (u['level'] as String? ?? ''),
          orElse: () => PlayerLevel.recreational,
        ),
        isAdmin: doc.id == adminId,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isAdmin) return -1;
        if (b.isAdmin) return 1;
        return a.name.compareTo(b.name);
      });
  });
});

/// Streams attendance confirmations for a specific group and game date label.
final _confirmationsProvider =
    StreamProvider.family<List<GameConfirmation>, (String, String)>(
        (ref, params) {
  final (groupId, gameDate) = params;
  if (gameDate.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('confirmations')
      .where('groupId', isEqualTo: groupId)
      .where('gameDate', isEqualTo: gameDate)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) {
            final d = doc.data();
            return GameConfirmation(
              userId: d['userId'] as String? ?? '',
              status: switch (d['status'] as String? ?? '') {
                'going' => ConfirmationStatus.going,
                'notGoing' => ConfirmationStatus.notGoing,
                _ => ConfirmationStatus.noReply,
              },
            );
          })
          .toList());
});

/// Streams upcoming events for the group ordered by dateTime.
/// Events where dateTime appears in cancelledDates are filtered out client-side.
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

class _RosterTab extends ConsumerWidget {
  final Group group;
  const _RosterTab({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final membersAsync = ref.watch(_membersProvider(group.id));
    final nextGame = group.nextGame ?? '';
    final confirmationsAsync =
        ref.watch(_confirmationsProvider((group.id, nextGame)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // ── Nearest game + confirmations ──────────────────────────────────
        if (nextGame.isNotEmpty) ...[
          SectionLabel('Najbliższy termin: $nextGame'),
          membersAsync.when(
            loading: _loadingCard,
            error: (_, __) =>
                _msgCard('Nie udało się załadować składu', t.label3),
            data: (members) {
              if (members.isEmpty) {
                return _msgCard('Brak członków', t.label3);
              }
              final confs = confirmationsAsync.valueOrNull ?? [];
              return IosCard(
                child: Column(
                  children: members.asMap().entries.map((e) {
                    final m = e.value;
                    final status = confs
                        .firstWhere(
                          (c) => c.userId == m.id,
                          orElse: () => GameConfirmation(
                              userId: m.id,
                              status: ConfirmationStatus.noReply),
                        )
                        .status;
                    return Column(children: [
                      IosRow(
                        leading: UserAvatar(name: m.name, size: 36),
                        title: Text(m.name,
                            style: AppTheme.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.label)),
                        trailing: _ConfirmationBadge(status: status),
                        showChevron: false,
                      ),
                      if (e.key < members.length - 1) const IosSeparator(),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],

        // ── All members ───────────────────────────────────────────────────
        const SectionLabel('Wszyscy członkowie'),
        membersAsync.when(
          loading: _loadingCard,
          error: (_, __) =>
              _msgCard('Nie udało się załadować składu', t.label3),
          data: (members) {
            if (members.isEmpty) {
              return _msgCard('Brak członków w grupie', t.label3);
            }
            return IosCard(
              child: Column(
                children: members.asMap().entries.map((e) {
                  final m = e.value;
                  return Column(children: [
                    IosRow(
                      leading: UserAvatar(name: m.name, size: 36),
                      title: Row(children: [
                        Flexible(
                          child: Text(m.name,
                              style: AppTheme.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: t.label)),
                        ),
                        if (m.isAdmin) ...[
                          const SizedBox(width: 6),
                          const ChipBadge('Admin',
                              variant: ChipVariant.orange),
                        ],
                      ]),
                      subtitle: Text(m.level.label,
                          style:
                              AppTheme.inter(fontSize: 13, color: t.label2)),
                      trailing: LevelDots(level: m.level),
                      showChevron: false,
                    ),
                    if (e.key < members.length - 1) const IosSeparator(),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Tab 2: Terminarz ─────────────────────────────────────────────────────────

class _ScheduleTab extends ConsumerWidget {
  final Group group;
  const _ScheduleTab({required this.group});

  void _showAddSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(groupId: group.id, uid: uid),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    // group.adminName stores the adminId (see GroupRepository._fromDoc)
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
                child: _EventTile(event: events[i], isAdmin: isAdmin),
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
              onTap: () => _showAddSheet(context, uid),
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

    final authRepo = ref.read(authRepositoryProvider);
    final uid = authRepo.currentUser?.uid ?? '';
    final userName = authRepo.currentUser?.displayName ?? 'Gracz';

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
              // Newest-first from Firestore + reverse: true = newest at bottom
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ConfirmationBadge extends StatelessWidget {
  final ConfirmationStatus status;
  const _ConfirmationBadge({required this.status});

  @override
  Widget build(BuildContext context) => switch (status) {
        ConfirmationStatus.going =>
          const ChipBadge('✓ Będę', variant: ChipVariant.green),
        ConfirmationStatus.notGoing =>
          const ChipBadge('✗ Nie mogę', variant: ChipVariant.red),
        ConfirmationStatus.noReply => ChipBadge('?',
            variant: ChipVariant.gray),
      };
}

class _EventTile extends StatelessWidget {
  final GroupEvent event;
  final bool isAdmin;
  const _EventTile({required this.event, this.isAdmin = false});

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Anulować termin?'),
        content: const Text('Termin zostanie oznaczony jako odwołany.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anuluj termin'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
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
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
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
    final dt = event.dateTime;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // ── Date box ────────────────────────────────────────────────────
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
                    style:
                        AppTheme.inter(fontSize: 11, color: AppColors.blue)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Info ─────────────────────────────────────────────────────────
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
                    style: AppTheme.inter(fontSize: 13, color: t.label2)),
              ],
            ),
          ),
          // ── Confirmed count ──────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${event.confirmedCount}',
                  style: AppTheme.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green)),
              Text('potw.',
                  style: AppTheme.inter(fontSize: 11, color: t.label3)),
            ],
          ),
          // ── Admin cancel ─────────────────────────────────────────────────
          if (isAdmin) ...[
            const SizedBox(width: 8),
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
          ],
        ],
      ),
    );
  }
}

// ─── Add Event Sheet ──────────────────────────────────────────────────────────

class _AddEventSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String uid;
  const _AddEventSheet({required this.groupId, required this.uid});

  @override
  ConsumerState<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<_AddEventSheet> {
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _loading = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  void _pickDateTime(BuildContext context) {
    final t = AppTokens.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
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
                    onPressed: () => Navigator.pop(context),
                    child: Text('Anuluj',
                        style: AppTheme.inter(
                            fontSize: 16, color: t.label2)),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
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
    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('events').add({
        'groupId': widget.groupId,
        'dateTime': Timestamp.fromDate(_selectedDate),
        'location': _locationCtrl.text.trim(),
        'createdBy': widget.uid,
        'confirmedIds': [],
        'cancelledDates': [],
      });
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
        '${dt.hour.toString().padLeft(2, '0')}:${(dt.minute ~/ 5 * 5).toString().padLeft(2, '0')}';

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
            TextFormField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'np. Hala sportowa, ul. Sportowa 1',
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
                prefixIcon: const Icon(CupertinoIcons.location_fill,
                    size: 16, color: AppColors.blue),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: AppTheme.inter(fontSize: 15, color: t.label),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Podaj lokalizację';
                }
                return null;
              },
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
            UserAvatar(name: msg.userName, size: 28),
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

// ─── Shared card helpers ──────────────────────────────────────────────────────

Widget _loadingCard() => const IosCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2.5),
        ),
      ),
    );

Widget _msgCard(String text, Color color) => IosCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(text,
              style: AppTheme.inter(fontSize: 14, color: color)),
        ),
      ),
    );
