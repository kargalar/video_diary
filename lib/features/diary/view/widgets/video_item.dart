import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../player_page.dart';

class VideoItem extends StatelessWidget {
  final dynamic entry;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const VideoItem({super.key, required this.entry, required this.onRename, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final path = entry.path as String;
    final date = entry.date as DateTime;
    final thumb = entry.thumbnailPath as String?;
    final durMs = entry.durationMs as int?;
    final bytes = entry.fileBytes as int?;
    final title = entry.title as String?;
    final durationText = durMs != null ? _formatDuration(Duration(milliseconds: durMs)) : '';
    final sizeText = bytes != null ? _formatSize(bytes) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(path),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              onPressed: (_) => onRename(),
              backgroundColor: const Color(0xFF5C5C5C),
              foregroundColor: Colors.white,
              icon: Icons.edit_outlined,
              label: 'Düzenle',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFF2C2C2C),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Sil',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openPlayer(context, path: path, title: title ?? _formatDate(date)),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                    child: thumb != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                            child: Image(image: FileImage(File(thumb)), width: 80, height: 80, fit: BoxFit.cover),
                          )
                        : Icon(Icons.videocam_outlined, size: 32, color: Colors.grey[400]),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title?.isNotEmpty == true ? title! : 'Untitled',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if ((entry.rating ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 12, color: Color(0xFF2C2C2C)),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${entry.rating}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF2C2C2C)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(date),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w300),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$durationText  •  $sizeText',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w300),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, {required String path, String? title}) {
    Navigator.of(context).pushNamed(
      PlayerPage.route,
      arguments: PlayerPageArgs(path: path, title: title),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(d.year, d.month, d.day);

    // Bugün ise sadece saat
    if (dateOnly == today) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    // Dün ise
    if (dateOnly == yesterday) {
      return 'Yesterday';
    }

    // Ay isimleri
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    final monthName = monthNames[d.month - 1];

    // Aynı yılda ise yıl gösterme
    if (d.year == now.year) {
      return '${d.day} $monthName';
    }

    // Farklı yılda ise yıl da göster
    return '${d.day} $monthName ${d.year}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }

  String _formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
    return '$bytes B';
  }
}
