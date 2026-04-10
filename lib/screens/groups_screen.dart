import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

// ─── Groups Screen ────────────────────────────────────────────────────────────

class GroupsScreen extends StatelessWidget {
  final void Function(Group) onOpenChat;

  const GroupsScreen({super.key, required this.onOpenChat});

  static const _members = [
    ('Marek K.', PlayerLevel.advanced, 'Atakujący', true),
    ('Anna W.', PlayerLevel.intermediate, 'Rozgrywający, Libero', false),
    ('Ty', PlayerLevel.advanced, 'Przyjmujący, Środkowy', false),
    ('Tomek B.', PlayerLevel.recreational, 'Zagrywający', false),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

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
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: t.label,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextButton(
                      onPressed: () {},
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
                        style: GoogleFonts.inter(
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
            _NotificationBanner(),
            const SizedBox(height: 4),
            const SectionLabel('Moje grupy'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(
                  children: MockData.groups.asMap().entries.map((e) {
                    final g = e.value;
                    final i = e.key;
                    return Column(children: [
                      _GroupRow(group: g, onTap: () => onOpenChat(g)),
                      if (i < MockData.groups.length - 1)
                        const IosSeparator(indent: 16),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SectionLabel('Ekipa Piątkowa – Skład'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(
                  children: _members.asMap().entries.map((e) {
                    final (name, level, pos, isAdmin) = e.value;
                    final isMe = name == 'Ty';
                    return Column(children: [
                      IosRow(
                        leading: UserAvatar(name: name, size: 36),
                        title: Row(children: [
                          Text(name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.label,
                              )),
                          if (isAdmin) ...[
                            const SizedBox(width: 6),
                            const ChipBadge('Admin',
                                variant: ChipVariant.orange),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            const ChipBadge('Ty', variant: ChipVariant.blue),
                          ],
                        ]),
                        subtitle: Text(pos,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: t.label2)),
                        trailing: LevelDots(level: level),
                      ),
                      if (e.key < _members.length - 1) const IosSeparator(),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }
}

// ── Notification Banner ───────────────────────────────────────────────────────

class _NotificationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ekipa Piątkowa',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.label)),
                  const SizedBox(height: 3),
                  Text('Admin otworzył zapisy na sobotę 10:00!',
                      style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _confirmBtn(context, '✓ Będę'),
                    const SizedBox(width: 8),
                    _confirmBtn(context, '✗ Nie mogę'),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmBtn(BuildContext context, String lbl) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.separator),
        ),
        child: Text(lbl,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: t.label)),
      ),
    );
  }
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
            emoji: group.emoji,
            size: 44,
            bgColor: group.isOpen
                ? AppColors.green.withOpacity(0.12)
                : AppColors.blue.withOpacity(0.12),
          ),
          title: Text(group.name,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w500, color: t.label)),
          subtitle: Row(children: [
            Text('${group.members} członków · ',
                style: GoogleFonts.inter(fontSize: 13, color: t.label2)),
            Text(
              group.isOpen ? 'Zapisy otwarte' : group.nextGame ?? '',
              style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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
    _messages = List.from(MockData.messages);
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
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, color: t.label)),
          Text('${widget.group.members} członków',
              style: GoogleFonts.inter(fontSize: 12, color: t.label2)),
        ]),
        actions: isAdmin
            ? [
                TextButton(
                  onPressed: () {},
                  child: Text('🔓 Otwórz',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.blue)),
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
        child: Text('📣 ${msg.text}',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.green)),
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
                      style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        color: msg.isMe ? Colors.white : t.label,
                        height: 1.4)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_fmt(msg.timestamp),
                    style: GoogleFonts.inter(fontSize: 11, color: t.label3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
