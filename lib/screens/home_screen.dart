import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/game_repository.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';

class HomeScreen extends ConsumerWidget {
  final UserProfile user;
  final void Function(NearbyGame) onOpenGame;
  final void Function(Group) onOpenGroup;
  final VoidCallback onGoGames;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onOpenGame,
    required this.onOpenGroup,
    required this.onGoGames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final gamesAsync = ref.watch(openGamesProvider);

    return CustomScrollView(
      slivers: [
        // ── Large-title nav ───────────────────────────────────────────────
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Witaj z powrotem',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: t.label2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.name.split(' ').first} 👋',
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: t.label,
                      letterSpacing: -0.5,
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

            // ── Hero banner ──────────────────────────────────────────────
            _HeroBanner(user: user),
            const SizedBox(height: 12),

            // ── Quick stats ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _QuickStat('🔥', '5 W', 'Seria'),
                  SizedBox(width: 10),
                  _QuickStat('⚡', '2.3', 'Asy/mecz'),
                  SizedBox(width: 10),
                  _QuickStat('📍', '1.2 km', 'Najbliższa'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Nearest games ────────────────────────────────────────────
            SectionLabel(
              'Gry w pobliżu',
              action: 'Zobacz wszystkie',
              onAction: onGoGames,
            ),
            gamesAsync.when(
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
                        'Nie udało się załadować gier',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: t.label3),
                      ),
                    ),
                  ),
                ),
              ),
              data: (games) {
                final preview = games.take(3).toList();
                if (preview.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IosCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Brak gier w pobliżu',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: t.label3),
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
                      children: preview.asMap().entries.map((e) {
                        final g = e.value;
                        final i = e.key;
                        return Column(
                          children: [
                            IosRow(
                              onTap: () => onOpenGame(g),
                              leading: SfIconBox(
                                emoji: g.category == GameCategory.beach
                                    ? '🏖️'
                                    : '🏛️',
                                bgColor: g.category == GameCategory.beach
                                    ? AppColors.orange.withValues(alpha: 0.12)
                                    : AppColors.blue.withValues(alpha: 0.12),
                              ),
                              title: Text(
                                g.title,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: t.label,
                                ),
                              ),
                              subtitle: Text(
                                '${g.location} · ${g.distanceKm} km',
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: t.label2),
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${g.dateTime.hour.toString().padLeft(2, '0')}:'
                                    '${g.dateTime.minute.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: g.matchesUser(user)
                                          ? AppColors.blue
                                          : t.label2,
                                    ),
                                  ),
                                  Text(
                                    'Dziś',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: t.label3),
                                  ),
                                ],
                              ),
                            ),
                            if (i < preview.length - 1)
                              const IosSeparator(),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Groups carousel ──────────────────────────────────────────
            SectionLabel(
              'Twoje grupy',
              action: 'Wszystkie',
              onAction: onGoGames,
            ),
            SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: MockData.groups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _GroupTile(
                  group: MockData.groups[i],
                  onTap: () => onOpenGroup(MockData.groups[i]),
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

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final UserProfile user;
  const _HeroBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF007AFF), Color(0xFF30B0C7)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -20,
            right: -10,
            child: Opacity(
              opacity: 0.12,
              child: Text('🏐', style: TextStyle(fontSize: 100)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEZON 2025',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _SeasonNum('24', 'Mecze'),
                  SizedBox(width: 28),
                  _SeasonNum('16', 'Wygrane'),
                  SizedBox(width: 28),
                  _SeasonNum('11.4', 'Pkt/mecz'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  LevelDots(level: user.level),
                  const SizedBox(width: 8),
                  Text(
                    user.level.label,
                    style:
                        GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  Text('·', style: GoogleFonts.inter(color: Colors.white38)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      user.positions.map((p) => p.label).join(', '),
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonNum extends StatelessWidget {
  final String value, label;
  const _SeasonNum(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
        ],
      );
}

// ── Quick Stat tile ───────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  final String emoji, value, label;
  const _QuickStat(this.emoji, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Expanded(
      child: IosCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.label,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: t.label2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group Tile ────────────────────────────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 156,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IosCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.label,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.members} członków',
                    style: GoogleFonts.inter(fontSize: 12, color: t.label3),
                  ),
                  const Spacer(),
                  Text(
                    group.isOpen ? '🔓 Zapisy otwarte' : '⏰ ${group.nextGame}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: group.isOpen ? AppColors.green : t.label3,
                    ),
                  ),
                ],
              ),
            ),
            if (group.unreadCount > 0)
              Positioned(
                top: -6,
                right: -6,
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
        ),
      ),
    );
  }
}
