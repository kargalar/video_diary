import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/diary_entry.dart';
import '../viewmodel/diary_view_model.dart';
import 'player_page.dart';

class CalendarPage extends StatefulWidget {
  static const route = '/calendar';
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth; // first day of month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiaryViewModel>();
    final entries = vm.entries;
    final byDay = _groupByDay(entries);
    final streakDays = _computeCurrentStreakDays(entries, vm.currentStreak);

    final monthName = _monthYearLabel(_currentMonth);
    final days = _buildMonthDays(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takvim'),
        centerTitle: true,
        actions: [IconButton(tooltip: 'Bugüne dön', icon: const Icon(Icons.today), onPressed: () => setState(() => _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1)))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(tooltip: 'Önceki ay', icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1))),
                  Text(monthName, style: Theme.of(context).textTheme.titleMedium),
                  IconButton(tooltip: 'Sonraki ay', icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1))),
                ],
              ),
            ),
            _WeekdayHeader(),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final d = days[index];
                  if (d == null) return const SizedBox.shrink();
                  final dayKey = _dateOnly(d);
                  final isToday = _isSameDate(dayKey, _dateOnly(DateTime.now()));
                  final hasEntries = byDay.containsKey(dayKey);
                  final inStreak = streakDays.contains(dayKey);
                  final isCurrentMonth = d.month == _currentMonth.month;
                  final count = byDay[dayKey]?.length ?? 0;
                  final rating = vm.getDailyAverageRating(dayKey);
                  final moods = vm.getMoodsForDay(dayKey);
                  return _DayCell(date: d, isCurrentMonth: isCurrentMonth, isToday: isToday, hasEntries: hasEntries, inStreak: inStreak, count: count, rating: rating, moods: moods, onTap: () => _showEntriesForDay(context, dayKey, byDay[dayKey] ?? []));
                },
              ),
            ),
            _Legend(),
          ],
        ),
      ),
    );
  }

  Map<DateTime, List<DiaryEntry>> _groupByDay(List<DiaryEntry> entries) {
    final map = <DateTime, List<DiaryEntry>>{};
    for (final e in entries) {
      final key = _dateOnly(e.date);
      map.putIfAbsent(key, () => []);
      map[key]!.add(e);
    }
    return map;
  }

  Set<DateTime> _computeCurrentStreakDays(List<DiaryEntry> entries, int currentStreak) {
    if (currentStreak <= 0) return {};
    final set = entries.map((e) => _dateOnly(e.date)).toSet();
    final today = _dateOnly(DateTime.now());
    DateTime? anchor;
    if (set.contains(today)) {
      anchor = today;
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (set.contains(yesterday)) anchor = yesterday;
    }
    if (anchor == null) return {};
    final res = <DateTime>{anchor};
    var cur = anchor;
    for (int i = 1; i < currentStreak; i++) {
      cur = cur.subtract(const Duration(days: 1));
      if (!set.contains(cur)) break;
      res.add(cur);
    }
    return res;
  }

  List<DateTime?> _buildMonthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7; // make Sunday = 0
    final list = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) {
      list.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      list.add(DateTime(month.year, month.month, d));
    }
    // pad to complete weeks
    while (list.length % 7 != 0) {
      list.add(null);
    }
    return list;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _monthYearLabel(DateTime d) => '${_monthNameTr(d.month)} ${d.year}';
  String _monthNameTr(int m) {
    const names = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return names[m - 1];
  }

  Future<void> _showEntriesForDay(BuildContext context, DateTime day, List<DiaryEntry> entries) async {
    entries.sort((a, b) => a.date.compareTo(b.date));
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final vm = ctx.read<DiaryViewModel>();
        int? rating = vm.getDailyAverageRating(day);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kayıtlar — ${day.day} ${_monthNameTr(day.month)} ${day.year}', style: Theme.of(ctx).textTheme.titleMedium),
                    Row(
                      children: [
                        const Text('Gün ort.: '),
                        StatefulBuilder(
                          builder: (context, setStateSb) {
                            Widget starIcon(int v) => Icon(v <= (rating ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 18);
                            return Row(children: [for (int i = 1; i <= 5; i++) starIcon(i)]);
                          },
                        ),
                        const SizedBox(width: 8),
                        StatefulBuilder(
                          builder: (context, setStateSb) => IconButton(
                            tooltip: 'Gün puanlarını temizle',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.backspace_outlined),
                            onPressed: () async {
                              await vm.clearRatingsForDay(day);
                              setStateSb(() => rating = null);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    int entryRating = e.rating ?? 0;
                    return ListTile(
                      leading: e.thumbnailPath != null ? Image.file(File(e.thumbnailPath!), width: 48, height: 48, fit: BoxFit.cover) : const Icon(Icons.videocam),
                      title: Text(e.title?.isNotEmpty == true ? e.title! : 'Video'),
                      subtitle: Text('${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}'),
                      trailing: StatefulBuilder(
                        builder: (context, setStateSb) {
                          Widget starBtn(int v) => IconButton(
                            tooltip: 'Videoyu $v yıldız yap',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            onPressed: () async {
                              final vm2 = ctx.read<DiaryViewModel>();
                              await vm2.setRatingForEntry(e.path, v);
                              setStateSb(() => entryRating = v);
                              // refresh day average display
                              rating = vm2.getDailyAverageRating(day);
                            },
                            icon: Icon(v <= entryRating ? Icons.star : Icons.star_border, color: Colors.amber),
                          );
                          return Row(mainAxisSize: MainAxisSize.min, children: [for (int i = 1; i <= 5; i++) starBtn(i)]);
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(
                          PlayerPage.route,
                          arguments: PlayerPageArgs(path: e.path, title: e.title),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const days = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(
          7,
          (i) => Expanded(
            child: Center(child: Text(days[i], style: Theme.of(context).textTheme.labelMedium)),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool hasEntries;
  final bool inStreak;
  final int count;
  final int? rating;
  final List<String> moods;
  final VoidCallback? onTap;
  const _DayCell({required this.date, required this.isCurrentMonth, required this.isToday, required this.hasEntries, required this.inStreak, required this.count, this.rating, this.moods = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Color by rating (explicit mapping to avoid overflow UI with stars)
    // Priority: streak > rating color > hasEntries > empty
    Color bg;
    if (inStreak) {
      bg = theme.colorScheme.secondaryContainer;
    } else if ((rating ?? 0) > 0) {
      switch (rating) {
        case 5:
          bg = Colors.green.withValues(alpha: 0.35);
          break;
        case 4:
          bg = Colors.lightGreen.withValues(alpha: 0.35);
          break;
        case 3:
          bg = Colors.amber.withValues(alpha: 0.35);
          break;
        case 2:
          bg = Colors.deepOrange.withValues(alpha: 0.30);
          break;
        case 1:
        default:
          bg = Colors.purple.withValues(alpha: 0.30);
      }
    } else if (hasEntries) {
      bg = theme.colorScheme.primaryContainer;
    } else {
      bg = theme.colorScheme.surface;
    }
    final fg = isCurrentMonth ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final border = isToday ? Border.all(color: theme.colorScheme.primary, width: 2) : null;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: border?.top ?? BorderSide.none),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${date.day}', style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
                  if (hasEntries)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(999)),
                      child: Text('$count', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary)),
                    ),
                ],
              ),
              const Spacer(),
              if (moods.isNotEmpty) Wrap(spacing: 1, runSpacing: 0, children: moods.take(4).map((m) => Text(_moodEmoji(m), style: const TextStyle(fontSize: 10))).toList()),
            ],
          ),
        ),
      ),
    );
  }

  String _moodEmoji(String id) {
    switch (id) {
      case 'mutlu':
        return '😊';
      case 'uzgun':
        return '😢';
      case 'kizgin':
        return '😠';
      case 'yorgun':
        return '😴';
      case 'hasta':
        return '🤒';
      default:
        return '🙂';
    }
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget dot(Color c, String t) => Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(t),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          dot(theme.colorScheme.secondaryContainer, 'Streak'),
          dot(theme.colorScheme.primaryContainer, 'Kayıt var'),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              const Text('Gün Puanı'),
            ],
          ),
          Row(children: [const Icon(Icons.circle_outlined, size: 14), const SizedBox(width: 4), const Text('Bugün')]),
        ],
      ),
    );
  }
}
