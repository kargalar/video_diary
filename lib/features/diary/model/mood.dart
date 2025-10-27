enum Mood {
  mutlu('😊', 'Happy'),
  uzgun('😢', 'Sad'),
  kizgin('😡', 'Angry'),
  sakin('😌', 'Calm'),
  endiseli('😰', 'Anxious'),
  yorgun('😴', 'Tired'),
  dusunceli('🤔', 'Thoughtful'),
  heyecanli('😍', 'Excited'),
  hayalKirikligi('😔', 'Disappointed'),
  minnettar('🥰', 'Grateful');

  final String emoji;
  final String label;

  const Mood(this.emoji, this.label);

  String get displayText => '$emoji $label';

  // JSON serialization
  static Mood? fromString(String value) {
    try {
      return Mood.values.firstWhere((m) => m.name == value);
    } catch (_) {
      return null;
    }
  }

  String toJson() => name;
}
