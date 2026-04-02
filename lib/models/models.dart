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

// ─── Group ────────────────────────────────────────────────────────────────────

class Group {
  final String id;
  final String name;
  final String emoji;
  final int members;
  final String adminName;
  final bool isOpen;
  final int unreadCount;
  final String? nextGame;

  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.members,
    required this.adminName,
    this.isOpen = false,
    this.unreadCount = 0,
    this.nextGame,
  });
}

// ─── ChatMessage ──────────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String senderName;
  final bool isMe;
  final String text;
  final DateTime timestamp;
  final bool isAnnouncement;

  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.isMe,
    required this.text,
    required this.timestamp,
    this.isAnnouncement = false,
  });
}

// ─── MatchRecord ──────────────────────────────────────────────────────────────

class MatchRecord {
  final String id;
  final String date;
  final String opponent;
  final bool isWin;
  final String score;
  final int points;
  final int aces;

  const MatchRecord({
    required this.id,
    required this.date,
    required this.opponent,
    required this.isWin,
    required this.score,
    required this.points,
    required this.aces,
  });
}