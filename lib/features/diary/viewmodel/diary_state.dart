import '../model/diary_entry.dart';

enum DiaryStatus { initial, loading, success, error }

class DiaryState {
  final DiaryStatus status;
  final List<DiaryEntry> entries;
  final Map<String, int> dailyRatings;
  final Map<String, List<String>> dailyMoods;
  final int currentStreak;
  final int maxStreak;
  final DateTime? lastRecordedDay;
  final String? errorMessage;

  const DiaryState({this.status = DiaryStatus.initial, this.entries = const [], this.dailyRatings = const {}, this.dailyMoods = const {}, this.currentStreak = 0, this.maxStreak = 0, this.lastRecordedDay, this.errorMessage});

  DiaryState copyWith({DiaryStatus? status, List<DiaryEntry>? entries, Map<String, int>? dailyRatings, Map<String, List<String>>? dailyMoods, int? currentStreak, int? maxStreak, DateTime? lastRecordedDay, String? errorMessage}) {
    return DiaryState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      dailyRatings: dailyRatings ?? this.dailyRatings,
      dailyMoods: dailyMoods ?? this.dailyMoods,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      lastRecordedDay: lastRecordedDay ?? this.lastRecordedDay,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
