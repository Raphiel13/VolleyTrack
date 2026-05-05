import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  LatLng _userLocation = const LatLng(52.2297, 21.0122);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) { return; }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    if (mounted) {
      setState(() =>
          _userLocation = LatLng(pos.latitude, pos.longitude));
    }
  }

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
    final groupGamesAsync = ref.watch(publicGroupGamesProvider);

    final allGames = <NearbyGame>[
      ...gamesAsync.valueOrNull ?? [],
      ...groupGamesAsync.valueOrNull ?? [],
    ].map((g) => g.copyWith(
          distanceKm: Geolocator.distanceBetween(
                _userLocation.latitude,
                _userLocation.longitude,
                g.latitude,
                g.longitude,
              ) /
              1000,
        ))
        .toList();

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
          data: (_) {
            final filtered = _applyFilters(allGames);
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
                  allGames: allGames,
                  filteredGames: filtered,
                  user: widget.user,
                  radius: _radius,
                  onOpen: _openGame,
                  userLocation: _userLocation,
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



LatLng _gameLatLng(NearbyGame game) =>
    LatLng(game.latitude, game.longitude);

/// Converts km radius to metres for the Circle widget.
double _kmToMetres(double km) => km * 1000;

class _MapView extends StatefulWidget {
  final List<NearbyGame> allGames;
  final List<NearbyGame> filteredGames;
  final UserProfile user;
  final double radius;
  final void Function(NearbyGame) onOpen;
  final LatLng userLocation;

  const _MapView({
    required this.allGames,
    required this.filteredGames,
    required this.user,
    required this.radius,
    required this.onOpen,
    required this.userLocation,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  GoogleMapController? _mapCtrl;
  late LatLng _searchCenter = widget.userLocation;
  late LatLng _cameraCenter = widget.userLocation;

  // Show the button only when the camera has drifted meaningfully from
  // the current search center (~100 m threshold avoids noise from zoom).
  bool get _showSearchHere {
    final dlat = (_cameraCenter.latitude - _searchCenter.latitude).abs();
    final dlng = (_cameraCenter.longitude - _searchCenter.longitude).abs();
    return dlat > 0.001 || dlng > 0.001;
  }

  String _fmtKm(double v) => v < 1
      ? '${(v * 1000).round()} m'
      : v == v.roundToDouble()
          ? '${v.round()} km'
          : '${v.toStringAsFixed(1)} km';

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('user_location'),
        position: widget.userLocation,
        infoWindow: const InfoWindow(title: 'Twoja pozycja'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
      ),
      for (final g in widget.filteredGames)
        Marker(
          markerId: MarkerId(g.id),
          position: _gameLatLng(g),
          infoWindow: InfoWindow(
            title: g.title,
            snippet: g.location,
            onTap: () => widget.onOpen(g),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            g.isGroupEvent
                ? BitmapDescriptor.hueViolet
                : g.matchesUser(widget.user)
                    ? BitmapDescriptor.hueAzure
                    : BitmapDescriptor.hueRed,
          ),
        ),
    };
  }

  Set<Circle> _buildCircle() {
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: _searchCenter,
        radius: _kmToMetres(widget.radius),
        fillColor: AppColors.blue.withValues(alpha: 0.08),
        strokeColor: AppColors.blue.withValues(alpha: 0.40),
        strokeWidth: 2,
      ),
    };
  }

  void _applySearchHere() {
    setState(() => _searchCenter = _cameraCenter);
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Map ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 300,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.userLocation,
                      zoom: 12,
                    ),
                    markers: _buildMarkers(),
                    circles: _buildCircle(),
                    onMapCreated: (c) => _mapCtrl = c,
                    onCameraMove: (pos) {
                      setState(() => _cameraCenter = pos.target);
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),

                  // 'Szukaj w tym obszarze' button
                  if (_showSearchHere)
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _applySearchHere,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search,
                                    size: 15, color: AppColors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  'Szukaj w tym obszarze',
                                  style: AppTheme.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Zoom buttons
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        _ZoomBtn(
                          label: '+',
                          onTap: () => _mapCtrl?.animateCamera(
                              CameraUpdate.zoomIn()),
                        ),
                        const SizedBox(height: 1),
                        _ZoomBtn(
                          label: '−',
                          onTap: () => _mapCtrl?.animateCamera(
                              CameraUpdate.zoomOut()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Count label ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            '${widget.filteredGames.length} gier w ${_fmtKm(widget.radius)}',
            style: AppTheme.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: t.label2,
            ),
          ),
        ),

        // ── List below map ────────────────────────────────────────────────
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
  final VoidCallback onTap;
  const _ZoomBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
            ),
          ],
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
      ),
    );
  }
}
