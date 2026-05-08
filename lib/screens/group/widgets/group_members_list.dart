import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/confirmations_repository.dart';
import '../../../repositories/events_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/ios_widgets.dart';
import '../providers/group_providers.dart';

// ─── GroupMembersList ─────────────────────────────────────────────────────────

/// Zakładka Skład — pokazuje potwierdzonych uczestników najbliższego terminu
/// lub pełną listę członków gdy brak nadchodzących wydarzeń
class GroupMembersList extends ConsumerWidget {
  final Group group;
  const GroupMembersList({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final isAdmin = uid.isNotEmpty && uid == group.adminName;

    // Najbliższy termin — pierwszy element posortowanej listy
    final nextEvent =
        ref.watch(groupEventsProvider(group.id)).valueOrNull?.firstOrNull;

    // Potwierdzone osoby dla tego terminu — pusty strumień gdy brak terminu
    final confirmedAsync = ref.watch(
        eventConfirmedProvider((nextEvent?.id ?? '', group.adminName)));

    // Wszyscy członkowie grupy — potrzebni do sekcji niepotwierdzonych admina
    final membersAsync = ref.watch(membersProvider(group.id));

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
                        color: groupAvatarColor(m.id)),
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
        final confirmedIds = confirmed.map((c) => c.id).toSet();
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
                          color: groupAvatarColor(m.id)),
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
                avatarColor: groupAvatarColor(m.id),
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

// ─── _MemberRow ───────────────────────────────────────────────────────────────

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
          bottom:
              showBottomRadius ? const Radius.circular(14) : Radius.zero,
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
              child: Divider(
                  height: 0.5, thickness: 0.5, color: t.separator),
            ),
        ],
      ),
    );
  }
}
