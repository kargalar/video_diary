class DiaryEntry {
  final String path; // absolute file path
  final DateTime date; // date of recording

  DiaryEntry({required this.path, required this.date});

  Map<String, dynamic> toJson() => {'path': path, 'date': date.toIso8601String()};

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(path: json['path'] as String, date: DateTime.parse(json['date'] as String));
}
