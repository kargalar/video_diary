import 'mood.dart';

class DiaryEntry {
  final String path; // absolute file path
  final DateTime date; // date of recording
  final String? thumbnailPath; // local thumbnail file
  final int? durationMs; // video duration in milliseconds
  final int? fileBytes; // file size in bytes
  final String? title; // user provided title
  final int? rating; // per-video rating 1..5
  final List<Mood>? moods; // mood tags for this entry

  DiaryEntry({required this.path, required this.date, this.thumbnailPath, this.durationMs, this.fileBytes, this.title, this.rating, this.moods});

  Map<String, dynamic> toJson() => {'path': path, 'date': date.toIso8601String(), 'thumbnailPath': thumbnailPath, 'durationMs': durationMs, 'fileBytes': fileBytes, 'title': title, 'rating': rating, 'moods': moods?.map((m) => m.toJson()).toList()};

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    path: json['path'] as String,
    date: DateTime.parse(json['date'] as String),
    thumbnailPath: json['thumbnailPath'] as String?,
    durationMs: (json['durationMs'] as num?)?.toInt(),
    fileBytes: (json['fileBytes'] as num?)?.toInt(),
    title: json['title'] as String?,
    rating: (json['rating'] as num?)?.toInt(),
    moods: (json['moods'] as List<dynamic>?)?.map((e) => Mood.fromString(e as String)).whereType<Mood>().toList(),
  );
}
