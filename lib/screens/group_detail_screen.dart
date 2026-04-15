import 'package:cloud_firestore/cloud_firestore.dart';
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

class GroupGame {
  final String id;
  final DateTime dateTime;
  final String location;
  final int confirmedCount;

  const GroupGame({
    required this.id,
    required this.dateTime,
    required this.location,
    required this.confirmedCount,
  });
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

/// Streams upcoming games for the group ordered by dateTime.
final _groupGamesProvider =
    StreamProvider.family<List<GroupGame>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('games')
      .where('groupId', isEqualTo: groupId)
      .where('dateTime', isGreaterThan: Timestamp.now())
      .orderBy('dateTime')
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final d = doc.data();
            final confirmed =
                List.from((d['confirmedIds'] as List?) ?? []);
            return GroupGame(
              id: doc.id,
              dateTime: (d['dateTime'] as Timestamp).toDate(),
              location: d['location'] as String? ?? '',
              confirmedCount: confirmed.length,
            );
          }).toList());
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final gamesAsync = ref.watch(_groupGamesProvider(group.id));

    return gamesAsync.when(
      loading: () => const Center(
        child:
            CircularProgressIndicator(color: AppColors.blue, strokeWidth: 2.5),
      ),
      error: (_, __) => Center(
        child: Text('Nie udało się załadować terminarza',
            style: AppTheme.inter(fontSize: 14, color: t.label3)),
      ),
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 44, color: t.label4),
                const SizedBox(height: 12),
                Text('Brak zaplanowanych gier',
                    style: AppTheme.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.label2)),
                const SizedBox(height: 4),
                Text('Dodaj pierwszy termin dla grupy',
                    style: AppTheme.inter(fontSize: 13, color: t.label3)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: games.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GameTile(game: games[i]),
          ),
        );
      },
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

class _GameTile extends StatelessWidget {
  final GroupGame game;
  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    const weekdays = ['', 'Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    const months = [
      '', 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
      'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
    ];
    final dt = game.dateTime;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
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
                Text(game.location,
                    style: AppTheme.inter(fontSize: 13, color: t.label2)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${game.confirmedCount}',
                  style: AppTheme.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green)),
              Text('potw.',
                  style: AppTheme.inter(fontSize: 11, color: t.label3)),
            ],
          ),
        ],
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
