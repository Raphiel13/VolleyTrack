import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/messages_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/ios_widgets.dart';
import '../providers/group_providers.dart';

// ─── GroupChatPanel ───────────────────────────────────────────────────────────

class GroupChatPanel extends ConsumerStatefulWidget {
  final Group group;
  const GroupChatPanel({super.key, required this.group});

  @override
  ConsumerState<GroupChatPanel> createState() => _GroupChatPanelState();
}

class _GroupChatPanelState extends ConsumerState<GroupChatPanel> {
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
      final name = await ref.read(userRepositoryProvider).getUserName(uid);
      if (name.isNotEmpty) userName = name;
    }
    if (userName.isEmpty) userName = 'Gracz';

    await ref.read(messagesRepositoryProvider).sendMessage(
          groupId: widget.group.id,
          userId: uid,
          userName: userName,
          text: text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final uid =
        ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final messagesAsync =
        ref.watch(groupMessagesProvider(widget.group.id));

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
                      style: AppTheme.inter(
                          fontSize: 14, color: t.label3)),
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
            border:
                Border(top: BorderSide(color: t.separator, width: 0.5)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration:
                    const InputDecoration(hintText: 'Wiadomość'),
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

// ─── _ChatBubble ──────────────────────────────────────────────────────────────

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
                color: groupAvatarColor(msg.userId)),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
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
                    style:
                        AppTheme.inter(fontSize: 11, color: t.label3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
