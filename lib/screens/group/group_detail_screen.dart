import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import 'widgets/group_chat_panel.dart';
import 'widgets/group_members_list.dart';
import 'widgets/group_schedule_tab.dart';

// ─── GroupDetailScreen ────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() =>
      _GroupDetailScreenState();
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: t.separator,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Kod zaproszenia',
                style: AppTheme.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.label)),
            const SizedBox(height: 6),
            Text('Podziel się kodem, aby zaprosić do grupy',
                style: AppTheme.inter(fontSize: 14, color: t.label2)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.2),
                    width: 1),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
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
                        color:
                            AppColors.blue.withValues(alpha: 0.12),
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
                style:
                    AppTheme.inter(fontSize: 12, color: t.label3)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final uid =
        ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.label),
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
          GroupMembersList(group: widget.group),
          GroupScheduleTab(group: widget.group),
          GroupChatPanel(group: widget.group),
        ],
      ),
    );
  }
}
