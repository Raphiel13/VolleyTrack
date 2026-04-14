import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'repositories/auth_repository.dart';
import 'theme/app_theme.dart';
import 'models/models.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/games_screen.dart';
import 'screens/game_detail_sheet.dart';
import 'screens/stats_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: VolleyManagerApp()));
}

// ─── Root App ─────────────────────────────────────────────────────────────────

class VolleyManagerApp extends StatefulWidget {
  const VolleyManagerApp({super.key});

  @override
  State<VolleyManagerApp> createState() => _VolleyManagerAppState();
}

class _VolleyManagerAppState extends State<VolleyManagerApp> {
  UserProfile _user = MockData.user;

  ThemeMode get _themeMode => switch (_user.themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VolleyManager',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: _AuthGate(
        user: _user,
        onUserChanged: (u) => setState(() => _user = u),
      ),
    );
  }
}

// ─── Auth Gate ────────────────────────────────────────────────────────────────

class _AuthGate extends ConsumerWidget {
  final UserProfile user;
  final ValueChanged<UserProfile> onUserChanged;

  const _AuthGate({required this.user, required this.onUserChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _SplashScreen(),
      error: (_, __) => const LoginScreen(),
      data: (firebaseUser) => firebaseUser == null
          ? const LoginScreen()
          : MainShell(user: user, onUserChanged: onUserChanged),
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: const Center(
        child: CircularProgressIndicator(
          color: AppColors.blue,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

// ─── Main Shell ───────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  final UserProfile user;
  final ValueChanged<UserProfile> onUserChanged;

  const MainShell({
    super.key,
    required this.user,
    required this.onUserChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.house),
      activeIcon: Icon(CupertinoIcons.house_fill),
      label: 'Start',
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.search),
      activeIcon: Icon(CupertinoIcons.search),
      label: 'Gry',
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.chart_bar),
      activeIcon: Icon(CupertinoIcons.chart_bar_fill),
      label: 'Statystyki',
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.person_2),
      activeIcon: Icon(CupertinoIcons.person_2_fill),
      label: 'Grupy',
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.person_circle),
      activeIcon: Icon(CupertinoIcons.person_circle_fill),
      label: 'Profil',
    ),
  ];

  void _switchTab(int i) {
    if (_tab == i) {
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final screens = [
      _TabNav(
        navKey: _navKeys[0],
        child: HomeScreen(
          user: widget.user,
          onOpenGame: (g) => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => GameDetailSheet(game: g),
          ),
          onOpenGroup: (g) {
            setState(() => _tab = 3);
            Future.delayed(const Duration(milliseconds: 50), () {
              _navKeys[3].currentState?.push(MaterialPageRoute(
                    builder: (_) => ChatScreen(group: g),
                  ));
            });
          },
          onGoGames: () => setState(() => _tab = 1),
        ),
      ),
      _TabNav(
        navKey: _navKeys[1],
        child: GamesScreen(user: widget.user),
      ),
      _TabNav(
        navKey: _navKeys[2],
        child: const StatsScreen(),
      ),
      _TabNav(
        navKey: _navKeys[3],
        child: GroupsScreen(
          onOpenChat: (g) => _navKeys[3].currentState?.push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(group: g),
                ),
              ),
        ),
      ),
      _TabNav(
        navKey: _navKeys[4],
        child: ProfileScreen(
          user: widget.user,
          onSave: (u) {
            widget.onUserChanged(u);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Profil zaktualizowany', style: AppTheme.inter()),
                backgroundColor: AppColors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
        ),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: t.separator, width: 0.5),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: const ColorFilter.mode(
              Colors.transparent,
              BlendMode.multiply,
            ),
            child: BottomNavigationBar(
              currentIndex: _tab,
              onTap: _switchTab,
              items: _navItems,
              backgroundColor: t.glassBg,
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tab Navigator ────────────────────────────────────────────────────────────

/// Wraps each tab's content in an independent [Navigator].
/// Allows each tab to maintain its own route stack.
/// Tapping the active tab pops to root via [MainShell._switchTab].
class _TabNav extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  final Widget child;

  const _TabNav({required this.navKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => child,
        settings: settings,
      ),
    );
  }
}
