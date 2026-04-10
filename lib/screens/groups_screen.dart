import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

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
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      child: Text(
                        '+ Nowa',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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

            // ── Notification banner ──────────────────────────────
            _NotificationBanner(),
            const SizedBox(height: 4),

            // ── Groups list ──────────────────────────────────────
            SectionLabel('Moje grupy'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(
                  children: MockData.groups
                      .asMap()
                      .entries
                      .map((e) {
                    final g = e.value;
                    final i = e.key;
                    return Column(children: [
                      _GroupRow(
                        group: g,
                        onTap: () => onOpenChat(g),
                      ),
                      if (i < MockData.groups.length - 1)
                        IosSeparator(indent: 16),
                    ]);
                  }).toList(),
                ),
              ),
            ),

            // ── Squad members ────────────────────────────────────
            SectionLabel('Ekipa Piątkowa – Skład'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IosCard(
                child: Column(
                  children: _members.asMap().entries.map((e) {
                    final (name, level, pos, isAdmin) = e.value;
                    final isMe = name == 'Ty';
                    return Column(children: [
                      IosRow(
                        leading:
                            UserAvatar(name: name, size: 36),
                        title: Row(children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: t.label,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 6),
                            ChipBadge('Admin',
                                variant: ChipVariant.orange),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            ChipBadge('Ty',
                                variant: ChipVariant.blue),
                          ],
                        ]),
                        subtitle: Text(
                          pos,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: t.label2),
                        ),
                        trailing: LevelDots(level: level),
                      ),
                      if (e.key < _members.length - 1)
                        IosSeparator(),
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
          border: Border.all(
              color: AppColors.green.withOpacity(0.2)),
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
                  Text(
                    'Ekipa Piątkowa',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.label,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Admin otworzył zapisy na sobotę 10:00!',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: t.label2),
                  ),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.separator),
        ),
        child: Text(
          lbl,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: t.label,
          ),
        ),
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
          title: Text(
            group.name,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: t.label,
            ),
          ),
          subtitle: Row(children: [
            Text(
              '${group.members} członków · ',
              style: GoogleFonts.inter(
                  fontSize: 13, color: t.label2),
            ),
            Text(
              group.isOpen
                  ? 'Zapisy otwarte'
                  : group.nextGame ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: group.isOpen
                    ? AppColors.green
                    : t.label2,
              ),
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
                child: Text(
                  '${group.unreadCount}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}