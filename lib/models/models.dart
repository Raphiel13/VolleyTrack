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

  Group copyWith({
    String? name,
    String? emoji,
    int? members,
    String? adminName,
    bool? isOpen,
    int? unreadCount,
    String? nextGame,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        members: members ?? this.members,
        adminName: adminName ?? this.adminName,
        isOpen: isOpen ?? this.isOpen,
        unreadCount: unreadCount ?? this.unreadCount,
        nextGame: nextGame ?? this.nextGame,
      );
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

// ─── MockData ─────────────────────────────────────────────────────────────────

class MockData {
  MockData._();

  static const user = UserProfile(
    id: 'user-1',
    name: 'Jan Kowalski',
    bio: 'Gram od 2021. Lubię 6×6 i turnieje plażowe.',
    level: PlayerLevel.advanced,
    positions: [PlayerPosition.outside, PlayerPosition.middle],
  );

  static final games = [
    NearbyGame(
      id: '1',
      title: 'Turniej 4×4',
      location: 'Hala przy Sienkiewicza',
      dateTime: DateTime.now().copyWith(hour: 18, minute: 30),
      level: PlayerLevel.intermediate,
      category: GameCategory.indoor,
      spotsTotal: 8,
      spotsTaken: 6,
      distanceKm: 1.2,
    ),
    NearbyGame(
      id: '2',
      title: 'Trening otwarty',
      location: 'Boisko Plażowe, Bałtycka',
      dateTime: DateTime.now()
          .add(const Duration(days: 1))
          .copyWith(hour: 10, minute: 0),
      level: PlayerLevel.beginner,
      category: GameCategory.beach,
      spotsTotal: 12,
      spotsTaken: 7,
      distanceKm: 4.8,
    ),
    NearbyGame(
      id: '3',
      title: 'Liga amatorska',
      location: 'OSiR Centrum',
      dateTime: DateTime.now()
          .add(const Duration(days: 1))
          .copyWith(hour: 20, minute: 0),
      level: PlayerLevel.advanced,
      category: GameCategory.indoor,
      spotsTotal: 10,
      spotsTaken: 9,
      distanceKm: 8.3,
    ),
    NearbyGame(
      id: '4',
      title: 'Casual 6×6',
      location: 'Park Miejski',
      dateTime: DateTime.now()
          .add(const Duration(days: 2))
          .copyWith(hour: 15, minute: 0),
      level: PlayerLevel.beginner,
      category: GameCategory.beach,
      spotsTotal: 12,
      spotsTaken: 8,
      distanceKm: 14.1,
    ),
    NearbyGame(
      id: '5',
      title: 'Volleyball Noc',
      location: 'Hala Sportowa Zachód',
      dateTime: DateTime.now()
          .add(const Duration(days: 4))
          .copyWith(hour: 21, minute: 0),
      level: PlayerLevel.intermediate,
      category: GameCategory.indoor,
      spotsTotal: 8,
      spotsTaken: 5,
      distanceKm: 22.5,
    ),
  ];

  static final groups = [
    const Group(
      id: '1',
      name: 'Ekipa Piątkowa',
      emoji: '🏐',
      members: 8,
      adminName: 'Marek K.',
      unreadCount: 3,
      nextGame: 'Sob, 10:00',
    ),
    const Group(
      id: '2',
      name: 'OSiR Liga – Drużyna A',
      emoji: '🏆',
      members: 12,
      adminName: 'Anna W.',
      isOpen: true,
      nextGame: 'Sob, 20:00',
    ),
    const Group(
      id: '3',
      name: 'Beach Summer 2025',
      emoji: '🏖️',
      members: 6,
      adminName: 'Ty',
      unreadCount: 1,
      nextGame: 'Nie, 15:00',
    ),
  ];

  static final messages = [
    ChatMessage(
      id: '1',
      senderName: 'Marek K.',
      isMe: false,
      text: 'Hej, jest 7/8 osób na sobotę! 🎉',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 38)),
    ),
    ChatMessage(
      id: '2',
      senderName: 'Anna W.',
      isMe: false,
      text: 'Super! Potwierdzam, będę o 10',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 25)),
    ),
    ChatMessage(
      id: '3',
      senderName: 'Ty',
      isMe: true,
      text: 'Ja też! Biorę piłki',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 23)),
    ),
    ChatMessage(
      id: '4',
      senderName: 'Marek K.',
      isMe: false,
      text: '🔔 Admin otworzył zapisy publiczne – brakuje 1 osoby',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isAnnouncement: true,
    ),
    ChatMessage(
      id: '5',
      senderName: 'Ty',
      isMe: true,
      text: 'Dobra, propagujemy po grupach?',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 57)),
    ),
    ChatMessage(
      id: '6',
      senderName: 'Anna W.',
      isMe: false,
      text: 'Już wrzuciłam na FB – ktoś powinien się zgłosić 💪',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 54)),
    ),
  ];

  static final matches = [
    const MatchRecord(
      id: '1',
      date: '18 maj',
      opponent: 'Ekipa Środa',
      isWin: true,
      score: '3–1',
      points: 14,
      aces: 2,
    ),
    const MatchRecord(
      id: '2',
      date: '12 maj',
      opponent: 'OSiR Liga Drużyna B',
      isWin: false,
      score: '1–3',
      points: 8,
      aces: 1,
    ),
    const MatchRecord(
      id: '3',
      date: '7 maj',
      opponent: 'Beach Casual',
      isWin: true,
      score: '2–0',
      points: 11,
      aces: 3,
    ),
    const MatchRecord(
      id: '4',
      date: '1 maj',
      opponent: 'Turniej Wiosna',
      isWin: true,
      score: '3–0',
      points: 18,
      aces: 4,
    ),
    const MatchRecord(
      id: '5',
      date: '24 kwi',
      opponent: 'Ekipa Środa',
      isWin: false,
      score: '2–3',
      points: 9,
      aces: 1,
    ),
    const MatchRecord(
      id: '6',
      date: '17 kwi',
      opponent: 'Casual Park',
      isWin: true,
      score: '2–1',
      points: 12,
      aces: 2,
    ),
  ];
}
