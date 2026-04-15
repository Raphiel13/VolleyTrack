import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/group_repository.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

// ─── Notification model & provider ───────────────────────────────────────────

class _GroupNotification {
  final String id;
  final String groupName;
  final String message;

  const _GroupNotification({
    required this.id,
    required this.groupName,
    required this.message,
  });
}

/// Streams the first unread notification for [userId] from the
/// 'notifications' collection. Emits null when there are none.
final _firstNotificationProvider =
    StreamProvider.family<_GroupNotification?, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .where('read', isEqualTo: false)
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final d = doc.data();
    return _GroupNotification(
      id: doc.id,
      groupName: d['groupName'] as String? ?? '',
      message: d['message'] as String? ?? '',
    );
  });
});

// ─── Icon picker data ─────────────────────────────────────────────────────────

const _kGroupIcons = <String, IconData>{
  'person_2_fill': CupertinoIcons.person_2_fill,
  'rosette': CupertinoIcons.rosette,
  'star_fill': CupertinoIcons.star_fill,
  'flame_fill': CupertinoIcons.flame_fill,
  'sportscourt_fill': CupertinoIcons.sportscourt_fill,
};

// ─── Groups Screen ────────────────────────────────────────────────────────────

class GroupsScreen extends ConsumerWidget {
  final void Function(Group) onOpenChat;

  const GroupsScreen({super.key, required this.onOpenChat});

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final groupsAsync = ref.watch(userGroupsProvider(uid));

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Grupy',
                    style: AppTheme.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: t.label,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextButton(
                      onPressed: () => _showCreateSheet(context),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        '+ Nowa',
                        style: AppTheme.inter(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            _NotificationBanner(uid: uid),
            const SizedBox(height: 4),
            const SectionLabel('Moje grupy'),
            groupsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: IosCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.blue,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: IosCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Nie udało się załadować grup',
                        style: AppTheme.inter(fontSize: 14, color: t.label3),
                      ),
                    ),
                  ),
                ),
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IosCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Nie należysz jeszcze do żadnej grupy',
                            style:
                                AppTheme.inter(fontSize: 14, color: t.label3),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IosCard(
                    child: Column(
                      children: groups.asMap().entries.map((e) {
                        final g = e.value;
                        final i = e.key;
                        return Column(children: [
                          _GroupRow(group: g, onTap: () => onOpenChat(g)),
                          if (i < groups.length - 1)
                            const IosSeparator(indent: 16),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }
}

// ── Notification Banner ───────────────────────────────────────────────────────

class _NotificationBanner extends ConsumerStatefulWidget {
  final String uid;
  const _NotificationBanner({required this.uid});

  @override
  ConsumerState<_NotificationBanner> createState() =>
      _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  bool? _attending;
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(begin: Offset.zero, end: const Offset(1.3, 0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInCubic));
    _fade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap(bool value) async {
    if (_attending != null) return;
    setState(() => _attending = value);
    // Mark notification as read in Firestore.
    final notif =
        ref.read(_firstNotificationProvider(widget.uid)).valueOrNull;
    if (notif != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(notif.id)
          .update({'read': true});
    }
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(_firstNotificationProvider(widget.uid));

    // Hide when loading, errored, or no unread notifications remain.
    final notif = notifAsync.valueOrNull;
    if (notif == null) return const SizedBox.shrink();

    final t = AppTokens.of(context);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.bell_fill,
                    size: 20, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notif.groupName,
                          style: AppTheme.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: t.label)),
                      const SizedBox(height: 3),
                      Text(notif.message,
                          style:
                              AppTheme.inter(fontSize: 13, color: t.label2)),
                      const SizedBox(height: 10),
                      Row(children: [
                        _confirmBtn(context, '✓ Będę', value: true),
                        const SizedBox(width: 8),
                        _confirmBtn(context, '✗ Nie mogę', value: false),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmBtn(BuildContext context, String lbl, {required bool value}) {
    final t = AppTokens.of(context);
    final isSelected = _attending == value;
    final activeColor = value ? AppColors.green : AppColors.red;
    return GestureDetector(
      onTap: () => _onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : t.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : t.separator,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(lbl,
            style: AppTheme.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? activeColor : t.label)),
      ),
    );
  }
}

// ── Group helpers ─────────────────────────────────────────────────────────────

IconData _groupIcon(Group group) {
  if (group.icon != null && _kGroupIcons.containsKey(group.icon)) {
    return _kGroupIcons[group.icon]!;
  }
  final n = group.name.toLowerCase();
  if (n.contains('beach') || n.contains('plaż')) return Icons.beach_access;
  if (n.contains('liga') || n.contains('turniej')) return Icons.emoji_events;
  return CupertinoIcons.person_2_fill;
}

Color _groupColor(String id) {
  const palette = <Color>[
    AppColors.blue,
    AppColors.teal,
    AppColors.green,
    AppColors.orange,
    AppColors.purple,
  ];
  return palette[id.hashCode.abs() % palette.length];
}

// ── Group Row ─────────────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupRow({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IosRow(
          onTap: onTap,
          leading: SfIconBox(
            iconWidget: Icon(
              _groupIcon(group),
              size: 24,
              color: _groupColor(group.id),
            ),
            size: 44,
            bgColor: group.isOpen
                ? AppColors.green.withValues(alpha: 0.12)
                : _groupColor(group.id).withValues(alpha: 0.12),
          ),
          title: Text(group.name,
              style: AppTheme.inter(
                  fontSize: 15, fontWeight: FontWeight.w500, color: t.label)),
          subtitle: Row(children: [
            Text('${group.members} członków · ',
                style: AppTheme.inter(fontSize: 13, color: t.label2)),
            Text(
              group.isOpen ? 'Zapisy otwarte' : group.nextGame ?? '',
              style: AppTheme.inter(
                  fontSize: 13,
                  color: group.isOpen ? AppColors.green : t.label2),
            ),
          ]),
        ),
        if (group.unreadCount > 0)
          Positioned(
            top: 8,
            right: 30,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: t.bg, width: 2),
              ),
              child: Center(
                child: Text('${group.unreadCount}',
                    style: AppTheme.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Create Group Sheet ───────────────────────────────────────────────────────

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedIcon = 'person_2_fill';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final uid =
        ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    try {
      await ref.read(groupRepositoryProvider).createGroup(
            name: _nameCtrl.text.trim(),
            adminId: uid,
            icon: _selectedIcon,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się utworzyć grupy',
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
            Text(
              'Nowa grupa',
              style: AppTheme.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.label),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Name field ───────────────────────────────────────────────
            Text('Nazwa grupy',
                style: AppTheme.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.label2)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'np. Ekipa Piątkowa',
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: AppTheme.inter(fontSize: 16, color: t.label),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'Nazwa musi mieć co najmniej 3 znaki';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Icon picker ──────────────────────────────────────────────
            Text('Ikona grupy',
                style: AppTheme.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.label2)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _kGroupIcons.entries.map((e) {
                final isSelected = _selectedIcon == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.blue.withValues(alpha: 0.12)
                          : t.bg2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.blue
                            : t.separator,
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Icon(
                      e.value,
                      size: 24,
                      color:
                          isSelected ? AppColors.blue : t.label3,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── Submit button ────────────────────────────────────────────
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
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Utwórz grupę',
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
    );
  }
}

// ─── Chat Screen ──────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final Group group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderName: 'Ty',
        isMe: true,
        text: text,
        timestamp: DateTime.now(),
      ));
    });
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isAdmin = widget.group.adminName == 'Ty';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.blue,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(widget.group.name,
              style: AppTheme.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, color: t.label)),
          Text('${widget.group.members} członków',
              style: AppTheme.inter(fontSize: 12, color: t.label2)),
        ]),
        actions: isAdmin
            ? [
                TextButton(
                  onPressed: () {},
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.lock_open, size: 14, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Text('Otwórz', style: AppTheme.inter(fontSize: 14, color: AppColors.blue)),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _MessageBubble(msg: _messages[i]),
            ),
          ),
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
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    if (msg.isAnnouncement) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(CupertinoIcons.speaker_2_fill, size: 14, color: AppColors.green),
            const SizedBox(width: 6),
            Flexible(
              child: Text(msg.text,
                  style: AppTheme.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            UserAvatar(name: msg.senderName, size: 28),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!msg.isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(msg.senderName,
                      style: AppTheme.inter(
                          fontSize: 11,
                          color: t.label3,
                          fontWeight: FontWeight.w500)),
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: msg.isMe ? AppColors.blue : t.bg2,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
                    bottomRight: Radius.circular(msg.isMe ? 4 : 18),
                  ),
                  boxShadow: msg.isMe
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Text(msg.text,
                    style: AppTheme.inter(
                        fontSize: 15,
                        color: msg.isMe ? Colors.white : t.label,
                        height: 1.4)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_fmt(msg.timestamp),
                    style: AppTheme.inter(fontSize: 11, color: t.label3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
