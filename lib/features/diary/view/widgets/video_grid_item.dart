import 'dart:io';

import 'package:flutter/material.dart';

import '../../model/mood.dart';
import '../player_page.dart';
import 'video_edit_bottom_sheet.dart';

class VideoGridItem extends StatelessWidget {
  final dynamic entry;
  final Function(Map<String, dynamic> updates) onEdit;
  final VoidCallback onDelete;

  const VideoGridItem({super.key, required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = entry.path as String;
    final date = entry.date as DateTime;
    final thumb = entry.thumbnailPath as String?;
    final title = entry.title as String?;
    final moods = (entry.moods as List<Mood>?) ?? [];
    final rating = entry.rating as int?;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        PlayerPage.route,
        arguments: PlayerPageArgs(path: path, title: title),
      ),
      onLongPress: () => _openEditBottomSheet(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail - fills container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: thumb != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.file(File(thumb), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      )
                    : Icon(Icons.videocam_outlined, size: 48, color: Colors.grey[400]),
              ),
            ),
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title?.isNotEmpty == true ? title! : 'Untitled',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Date
                  Text(_formatDate(date), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  // Moods and Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Moods
                      if (moods.isNotEmpty)
                        Expanded(
                          child: Wrap(spacing: 2, children: moods.take(3).map((mood) => Text(mood.emoji, style: const TextStyle(fontSize: 14))).toList()),
                        ),
                      // Rating
                      if ((rating ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '$rating',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.amber),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditBottomSheet(BuildContext context) async {
    final title = entry.title as String?;
    final rating = entry.rating as int?;
    final moods = (entry.moods as List<Mood>?) ?? [];

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: VideoEditBottomSheet(currentTitle: title ?? '', currentRating: rating, currentMoods: moods),
      ),
    );

    if (result != null) {
      onEdit(result);
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(d.year, d.month, d.day);

    if (dateOnly == today) {
      return 'Today ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    if (dateOnly == yesterday) {
      return 'Yesterday';
    }

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = monthNames[d.month - 1];

    if (d.year == now.year) {
      return '${d.day} $monthName';
    }

    return '${d.day} $monthName ${d.year}';
  }
}
