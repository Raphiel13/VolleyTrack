import 'package:cloud_firestore/cloud_firestore.dart';

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
  middle('Środkowy');

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
  final String? photoUrl;

  const UserProfile({
    required this.id,
    required this.name,
    this.bio = '',
    this.level = PlayerLevel.recreational,
    this.positions = const [],
    this.themeMode = AppThemeMode.system,
    this.photoUrl,
  });

  UserProfile copyWith({
    String? name,
    String? bio,
    PlayerLevel? level,
    List<PlayerPosition>? positions,
    AppThemeMode? themeMode,
    String? photoUrl,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        level: level ?? this.level,
        positions: positions ?? this.positions,
        themeMode: themeMode ?? this.themeMode,
        photoUrl: photoUrl ?? this.photoUrl,
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
  final double latitude;
  final double longitude;
  final bool isGroupEvent;
  final String organizerId;
  final double? price;

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
    this.organizerName = '',
    this.organizerRating = 0.0,
    this.latitude = 52.2297,
    this.longitude = 21.0122,
    this.isGroupEvent = false,
    this.organizerId = '',
    this.price,
  });

  int get spotsLeft => spotsTotal - spotsTaken;
  bool get isFull => spotsLeft <= 0;

  bool matchesUser(UserProfile user) => level == user.level;

  NearbyGame copyWith({double? distanceKm}) => NearbyGame(
        id: id,
        title: title,
        location: location,
        dateTime: dateTime,
        level: level,
        category: category,
        spotsTotal: spotsTotal,
        spotsTaken: spotsTaken,
        distanceKm: distanceKm ?? this.distanceKm,
        organizerName: organizerName,
        organizerRating: organizerRating,
        latitude: latitude,
        longitude: longitude,
        isGroupEvent: isGroupEvent,
        organizerId: organizerId,
        price: price,
      );

  factory NearbyGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return NearbyGame(
      id: doc.id,
      title: d['title'] as String,
      location: d['location'] as String,
      dateTime: (d['dateTime'] as Timestamp).toDate(),
      level: PlayerLevel.values.byName(d['level'] as String),
      category: GameCategory.values.byName(d['category'] as String),
      spotsTotal: d['spotsTotal'] as int,
      spotsTaken: d['spotsTaken'] as int,
      organizerName: d['organizerName'] as String? ?? '',
      organizerRating: (d['organizerRating'] as num?)?.toDouble() ?? 0.0,
      distanceKm: 0.0,
      latitude: (d['latitude'] as num?)?.toDouble() ?? 52.2297,
      longitude: (d['longitude'] as num?)?.toDouble() ?? 21.0122,
      organizerId: d['organizerId'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'location': location,
        'dateTime': Timestamp.fromDate(dateTime),
        'level': level.name,
        'category': category.name,
        'spotsTotal': spotsTotal,
        'spotsTaken': spotsTaken,
        'organizerName': organizerName,
        'organizerRating': organizerRating,
        'isOpen': !isFull,
        'playerIds': <String>[],
      };
}

// ─── Group ────────────────────────────────────────────────────────────────────

class Group {
  final String id;
  final String name;
  final int members;
  final String adminName;
  final bool isOpen;
  final int unreadCount;
  final String? nextGame;
  final String? icon;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.adminName,
    this.isOpen = false,
    this.unreadCount = 0,
    this.nextGame,
    this.icon,
  });

  Group copyWith({
    String? name,
    int? members,
    String? adminName,
    bool? isOpen,
    int? unreadCount,
    String? nextGame,
    String? icon,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        members: members ?? this.members,
        adminName: adminName ?? this.adminName,
        isOpen: isOpen ?? this.isOpen,
        unreadCount: unreadCount ?? this.unreadCount,
        nextGame: nextGame ?? this.nextGame,
        icon: icon ?? this.icon,
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
