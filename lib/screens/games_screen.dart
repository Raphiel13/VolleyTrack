import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/game_repository.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/ios_widgets.dart';
import 'game_detail_sheet.dart';

enum _ViewMode { list, map }

class GamesScreen extends ConsumerStatefulWidget {
  final UserProfile user;
  const GamesScreen({super.key, required this.user});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  _ViewMode _view = _ViewMode.list;
  String _search = '';
  PlayerLevel? _filterLevel;
  GameCategory? _filterCat;
  double _radius = 10.0;

  List<NearbyGame> _applyFilters(List<NearbyGame> games) =>
      games.where((g) {
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
    final gamesAsync = ref.watch(openGamesProvider);

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Znajdź grę',
                style: AppTheme.inter(
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
        gamesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: _LoadingView(),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: _ErrorView(
              onRetry: () => ref.invalidate(openGamesProvider),
            ),
          ),
          data: (games) {
            final filtered = _applyFilters(games);
            if (_view == _ViewMode.list) {
              return SliverToBoxAdapter(
                child: _ListView(
                  games: filtered,
                  user: widget.user,
                  radius: _radius,
                  onOpen: _openGame,
                ),
              );
            } else {
              return SliverToBoxAdapter(
                child: _MapView(
                  allGames: games,
                  filteredGames: filtered,
                  user: widget.user,
                  radius: _radius,
                  onOpen: _openGame,
                ),
              );
            }
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Loading View ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.blue,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Nie udało się pobrać gier',
            style: AppTheme.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: t.label,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sprawdź połączenie i spróbuj ponownie',
            style: AppTheme.inter(fontSize: 14, color: t.label3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Spróbuj ponownie',
              style: AppTheme.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.blue,
              ),
            ),
          ),
        ],
      ),
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
          // Search bar
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
                Icon(Icons.search, size: 17, color: t.label3),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: 'Szukaj gier, lokalizacji…',
                      border: InputBorder.none,
                      hintStyle:
                          AppTheme.inter(fontSize: 17, color: t.label3),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    style: AppTheme.inter(fontSize: 17, color: t.label),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Segmented control + filter chips
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
                            context,
                            l.label,
                            filterLevel == l,
                            () => onLevel(l),
                          )),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: t.separator,
                      ),
                      _chip(
                        context,
                        '🏛️ Hala',
                        filterCat == GameCategory.indoor,
                        () => onCat(filterCat == GameCategory.indoor
                            ? null
                            : GameCategory.indoor),
                      ),
                      _chip(
                        context,
                        '🏖️ Plaża',
                        filterCat == GameCategory.beach,
                        () => onCat(filterCat == GameCategory.beach
                            ? null
                            : GameCategory.beach),
                      ),
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

  Widget _chip(BuildContext ctx, String lbl, bool active, VoidCallback onTap) {
    final t = AppTokens.of(ctx);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.blue : const Color(0x1E767680),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          lbl,
          style: AppTheme.inter(
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
              style: AppTheme.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.label,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Zwiększ zasięg powyżej',
              style: AppTheme.inter(fontSize: 14, color: t.label3),
            ),
          ],
        ),
      );
    }

    final matchGames = games.where((g) => g.matchesUser(user)).toList();
    final otherGames = games.where((g) => !g.matchesUser(user)).toList();

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
                    game: g,
                    isMatch: true,
                    onTap: () => onOpen(g),
                  ),
                )),
          ],
          if (otherGames.isNotEmpty) ...[
            if (matchGames.isNotEmpty) const SizedBox(height: 4),
            _divider(context, 'Pozostałe gry'),
            ...otherGames.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GameCard(game: g, onTap: () => onOpen(g)),
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
          Expanded(child: Divider(color: AppTokens.of(context).separator)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: AppTheme.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.blue,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppTokens.of(context).separator)),
        ],
      ),
    );
  }
}

// ── Map View ──────────────────────────────────────────────────────────────────

class _MapView extends StatefulWidget {
  final List<NearbyGame> allGames;
  final List<NearbyGame> filteredGames;
  final UserProfile user;
  final double radius;
  final void Function(NearbyGame) onOpen;

  const _MapView({
    required this.allGames,
    required this.filteredGames,
    required this.user,
    required this.radius,
    required this.onOpen,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  NearbyGame? _pinSelected;

  static const _positions = {
    '1': (0.52, 0.48),
    '2': (0.62, 0.36),
    '3': (0.36, 0.58),
    '4': (0.68, 0.66),
    '5': (0.28, 0.30),
  };

  String _fmtKm(double v) => v < 1
      ? '${(v * 1000).round()} m'
      : v == v.roundToDouble()
          ? '${v.round()} km'
          : '${v.toStringAsFixed(1)} km';

  // ── Pin bubble widget ────────────────────────────────────────────
  Widget _buildPinBubble(NearbyGame g, bool isMatch, {required bool inRadius}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isMatch && inRadius ? AppColors.blue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                g.category == GameCategory.beach ? '🏖️' : '🏛️',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 4),
              Text(
                g.title,
                style: AppTheme.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMatch && inRadius
                      ? Colors.white
                      : const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMatch && inRadius ? AppColors.blue : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rFrac = (widget.radius / 50.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 240,
              child: LayoutBuilder(builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final rPx = (rFrac * 100 + 20).clamp(20.0, 120.0);

                return Stack(
                  children: [
                    // Background
                    Container(color: const Color(0xFFE8F0E9)),
                    // Grid
                    CustomPaint(painter: _GridPainter(), size: Size(w, h)),
                    // Roads
                    CustomPaint(painter: _RoadsPainter(), size: Size(w, h)),

                    // Radius ring
                    Positioned(
                      left: w * 0.52 - rPx,
                      top: h * 0.52 - rPx,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.elasticOut,
                        width: rPx * 2,
                        height: rPx * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.blue.withOpacity(0.07),
                          border: Border.all(
                            color: AppColors.blue.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // User dot
                    Positioned(
                      left: w * 0.52 - 9,
                      top: h * 0.52 - 9,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.blue,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pins in radius – interactive
                    ...widget.allGames
                        .where((g) => widget.filteredGames.contains(g))
                        .map((g) {
                      final pos = _positions[g.id];
                      if (pos == null) return const SizedBox();
                      final isMatch = g.matchesUser(widget.user);
                      return Positioned(
                        left: w * pos.$1 - 40,
                        top: h * pos.$2 - 36,
                        child: GestureDetector(
                          onTap: () => setState(() => _pinSelected =
                              _pinSelected?.id == g.id ? null : g),
                          child: _buildPinBubble(g, isMatch, inRadius: true),
                        ),
                      );
                    }),

                    // Pins outside radius – non-interactive, greyed out
                    ...widget.allGames
                        .where((g) => !widget.filteredGames.contains(g))
                        .map((g) {
                      final pos = _positions[g.id];
                      if (pos == null) return const SizedBox();
                      return Positioned(
                        left: w * pos.$1 - 40,
                        top: h * pos.$2 - 36,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.25,
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                              child: _buildPinBubble(g, false, inRadius: false),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Radius label
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            '⬤ ${_fmtKm(widget.radius)}',
                            style: AppTheme.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Zoom buttons
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: Column(children: [
                        _ZoomBtn('+'),
                        SizedBox(height: 1),
                        _ZoomBtn('−'),
                      ]),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),

        // Selected pin card
        if (_pinSelected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: GameCard(
              game: _pinSelected!,
              isMatch: _pinSelected!.matchesUser(widget.user),
              onTap: () => widget.onOpen(_pinSelected!),
            ),
          ),

        // Count label
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            '${widget.filteredGames.length} gier w ${_fmtKm(widget.radius)}',
            style: AppTheme.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTokens.of(context).label2,
            ),
          ),
        ),

        // List below map
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: widget.filteredGames
                .map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GameCard(
                        game: g,
                        isMatch: g.matchesUser(widget.user),
                        onTap: () => widget.onOpen(g),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────

class _ZoomBtn extends StatelessWidget {
  final String label;
  const _ZoomBtn(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    road
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 10;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.50)
        ..quadraticBezierTo(size.width * 0.4, size.height * 0.33,
            size.width * 0.6, size.height * 0.50)
        ..quadraticBezierTo(size.width * 0.8, size.height * 0.65, size.width,
            size.height * 0.44),
      road,
    );

    road
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 7;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.70)
        ..quadraticBezierTo(size.width * 0.3, size.height * 0.78,
            size.width * 0.6, size.height * 0.62)
        ..quadraticBezierTo(size.width * 0.8, size.height * 0.55, size.width,
            size.height * 0.70),
      road,
    );

    road
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 9;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.43, 0)
        ..quadraticBezierTo(size.width * 0.46, size.height * 0.45,
            size.width * 0.50, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
