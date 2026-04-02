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

// ─── NearbyGame ───────────────────────────────────────────────────────────────

class NearbyGame {
  final String id;
  final String title;
  final String location;
  final DateTime dateTime;
  final PlayerLevel level;
  final GameCategory category;
  final int spotsTotal;
  final int spotsTaken;
  final double distanceKm;
  final String organizerName;
  final double organizerRating;

  const NearbyGame({
    required this.id,
    required this.title,
    required this.location,
    required this.dateTime,
    required this.level,
    required this.category,
    required this.spotsTotal,
    required this.spotsTaken,
    required this.distanceKm,
    this.organizerName = 'Marek K.',
    this.organizerRating = 4.9,
  });

  int get spotsLeft => spotsTotal - spotsTaken;
  bool get isFull => spotsLeft <= 0;

  bool matchesUser(UserProfile user) => level == user.level;
}