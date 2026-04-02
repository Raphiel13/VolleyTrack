// ─── Domain enums ─────────────────────────────────────────────────────────────
 
enum PlayerLevel {
  beginner('Początkujący'),
  recreational('Rekreacyjny'),
  intermediate('Średni'),
  advanced('Zaawansowany'),
  competitive('Wyczynowy');
 
  const PlayerLevel(this.label);
  final String label;
}
 
enum PlayerPosition {
  outside('Przyjmujący'),
  setter('Rozgrywający'),
  opposite('Atakujący'),
  libero('Libero'),
  middle('Środkowy'),
  server('Zagrywający');
 
  const PlayerPosition(this.label);
  final String label;
}
 
enum GameCategory { indoor, beach }
 
enum MemberRole { coach, player, assistant }

// ─── UserProfile ──────────────────────────────────────────────────────────────

enum AppThemeMode { light, dark, system }

class UserProfile {
  final String id;
  final String name;
  final String bio;
  final PlayerLevel level;
  final List<PlayerPosition> positions;
  final AppThemeMode themeMode;

  const UserProfile({
    required this.id,
    required this.name,
    this.bio = '',
    this.level = PlayerLevel.recreational,
    this.positions = const [],
    this.themeMode = AppThemeMode.system,
  });

  UserProfile copyWith({
    String? name,
    String? bio,
    PlayerLevel? level,
    List<PlayerPosition>? positions,
    AppThemeMode? themeMode,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        level: level ?? this.level,
        positions: positions ?? this.positions,
        themeMode: themeMode ?? this.themeMode,
      );
}