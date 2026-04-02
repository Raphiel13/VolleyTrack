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