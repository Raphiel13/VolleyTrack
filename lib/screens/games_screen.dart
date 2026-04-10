import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';
import 'game_detail_sheet.dart';

enum _ViewMode { list, map }

class GamesScreen extends StatefulWidget {
  final UserProfile user;
  const GamesScreen({super.key, required this.user});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  _ViewMode _view = _ViewMode.list;
  String _search = '';
  PlayerLevel? _filterLevel;
  GameCategory? _filterCat;
  double _radius = 10.0;

  List<NearbyGame> get _filtered => MockData.games.where((g) {
        final ms = _search.isEmpty ||
            g.title.toLowerCase().contains(_search.toLowerCase()) ||
            g.location.toLowerCase().contains(_search.toLowerCase());
        final ml = _filterLevel == null || g.level == _filterLevel;
        final mc = _filterCat == null || g.category == _filterCat;
        final mr = g.distanceKm <= _radius;
        return ms && ml && mc && mr;
      }).toList();

  void _openGame(NearbyGame g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameDetailSheet(game: g),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Znajdź grę',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: t.label,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterHeader(
            search: _search,
            onSearch: (v) => setState(() => _search = v),
            view: _view,
            onView: (v) => setState(() => _view = v),
            filterLevel: _filterLevel,
            onLevel: (l) => setState(() => _filterLevel = l),
            filterCat: _filterCat,
            onCat: (c) => setState(() => _filterCat = c),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: KmSlider(
              value: _radius,
              onChanged: (v) => setState(() => _radius = v),
            ),
          ),
        ),
        if (_view == _ViewMode.list)
          SliverToBoxAdapter(
            child: _ListView(
              games: _filtered,
              user: widget.user,
              radius: _radius,
              onOpen: _openGame,
            ),
          )
        else
          SliverToBoxAdapter(
            child: _MapPlaceholder(radius: _radius),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Filter Header ─────────────────────────────────────────────────────────────

class _FilterHeader extends SliverPersistentHeaderDelegate {
  final String search;
  final ValueChanged<String> onSearch;
  final _ViewMode view;
  final ValueChanged<_ViewMode> onView;
  final PlayerLevel? filterLevel;
  final ValueChanged<PlayerLevel?> onLevel;
  final GameCategory? filterCat;
  final ValueChanged<GameCategory?> onCat;

  _FilterHeader({
    required this.search,
    required this.onSearch,
    required this.view,
    required this.onView,
    required this.filterLevel,
    required this.onLevel,
    required this.filterCat,
    required this.onCat,
  });

  @override
  double get minExtent => maxExtent;
  @override
  double get maxExtent => 110;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = AppTokens.of(context);
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: t.bg == AppTokens.dark.bg
                  ? const Color(0xFF2C2C2E)
                  : const Color(0x1E767680),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(CupertinoIcons.search, size: 17, color: t.label3),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: 'Szukaj gier, lokalizacji…',
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.inter(
                          fontSize: 17, color: t.label3),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    style: GoogleFonts.inter(
                        fontSize: 17, color: t.label),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: IosSegmentedControl<_ViewMode>(
                  options: const [
                    (_ViewMode.list, '☰ Lista'),
                    (_ViewMode.map, '🗺 Mapa'),
                  ],
                  selected: view,
                  onChanged: onView,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(context, 'Wszystkie', filterLevel == null,
                          () => onLevel(null)),
                      ...PlayerLevel.values.map((l) => _chip(
                          context, l.label, filterLevel == l,
                          () => onLevel(l))),
                      Container(
                        width: 1, height: 20,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 6),
                        color: t.separator,
                      ),
                      _chip(context, '🏛️ Hala',
                          filterCat == GameCategory.indoor,
                          () => onCat(filterCat == GameCategory.indoor
                              ? null
                              : GameCategory.indoor)),
                      _chip(context, '🏖️ Plaża',
                          filterCat == GameCategory.beach,
                          () => onCat(filterCat == GameCategory.beach
                              ? null
                              : GameCategory.beach)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext ctx, String lbl, bool active, VoidCallback onTap) {
    final t = AppTokens.of(ctx);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 7),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.blue : const Color(0x1E767680),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          lbl,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : t.label,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterHeader old) => true;
}

// ── List View ─────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final List<NearbyGame> games;
  final UserProfile user;
  final double radius;
  final void Function(NearbyGame) onOpen;

  const _ListView({
    required this.games,
    required this.user,
    required this.radius,
    required this.onOpen,
  });

  String _fmtKm(double v) => v < 1
      ? '${(v * 1000).round()} m'
      : v == v.roundToDouble()
          ? '${v.round()} km'
          : '${v.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    if (games.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Brak gier w promieniu ${_fmtKm(radius)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.label,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Zwiększ zasięg powyżej',
              style: GoogleFonts.inter(
                  fontSize: 14, color: t.label3),
            ),
          ],
        ),
      );
    }

    final matchGames =
        games.where((g) => g.matchesUser(user)).toList();
    final otherGames =
        games.where((g) => !g.matchesUser(user)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (matchGames.isNotEmpty) ...[
            _divider(context, '✦ Dopasowane do Twojego profilu'),
            ...matchGames.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GameCard(
                      game: g, isMatch: true, onTap: () => onOpen(g)),
                )),
          ],
          if (otherGames.isNotEmpty) ...[
            if (matchGames.isNotEmpty) const SizedBox(height: 4),
            _divider(context, 'Pozostałe gry'),
            ...otherGames.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child:
                      GameCard(game: g, onTap: () => onOpen(g)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _divider(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
              child:
                  Divider(color: AppTokens.of(context).separator)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.blue,
              ),
            ),
          ),
          Expanded(
              child:
                  Divider(color: AppTokens.of(context).separator)),
        ],
      ),
    );
  }
}

// ── Map placeholder ───────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  final double radius;
  const _MapPlaceholder({required this.radius});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 240,
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(
        child: Text('🗺️', style: TextStyle(fontSize: 48)),
      ),
    );
  }
}