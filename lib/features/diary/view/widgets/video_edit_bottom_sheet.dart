import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/mood.dart';

class VideoEditBottomSheet extends StatefulWidget {
  final String currentTitle;
  final int? currentRating;
  final List<Mood> currentMoods;
  final bool showDeleteButton;
  final DateTime? currentDate;
  final bool isNewVideo;

  const VideoEditBottomSheet({
    super.key,
    required this.currentTitle,
    this.currentRating,
    required this.currentMoods,
    this.showDeleteButton = false,
    this.currentDate,
    this.isNewVideo = false,
  });

  @override
  State<VideoEditBottomSheet> createState() => _VideoEditBottomSheetState();
}

class _VideoEditBottomSheetState extends State<VideoEditBottomSheet> {
  late TextEditingController _titleController;
  late int _rating;
  late Set<Mood> _selectedMoods;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _rating = widget.currentRating ?? 0;
    _selectedMoods = widget.currentMoods.toSet();
    _selectedDate = widget.currentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getResult() {
    return {
      'title': _titleController.text.trim(),
      'rating': _rating == 0 ? null : _rating,
      'moods': _selectedMoods.toList(),
      if (kDebugMode) 'date': _selectedDate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (widget.isNewVideo) {
            // Show warning dialog for new videos
            final shouldClose = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard video?'),
                content: const Text(
                  'If you close without saving, the video will be deleted.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (shouldClose == true && context.mounted) {
              Navigator.of(context).pop({'discard': true});
            }
          } else {
            Navigator.of(context).pop(_getResult());
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isNewVideo ? 'Save Video' : 'Edit Diary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (widget.isNewVideo)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        final shouldClose = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Discard video?'),
                            content: const Text(
                              'If you close without saving, the video will be deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Discard'),
                              ),
                            ],
                          ),
                        );
                        if (shouldClose == true && context.mounted) {
                          Navigator.of(context).pop({'discard': true});
                        }
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Video title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Debug: Date picker
                    if (kDebugMode) ...[
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(5, (index) {
                          final starValue = index + 1;
                          final isSelected = starValue <= _rating;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = starValue),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 32,
                                color: isSelected
                                    ? Colors.amber[600]
                                    : Colors.grey[300],
                              ),
                            ),
                          );
                        }),
                        if (_rating > 0) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _rating = 0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Moods
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mood',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: Mood.values.map((mood) {
                        final isSelected = _selectedMoods.contains(mood);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedMoods.remove(mood);
                              } else {
                                _selectedMoods.add(mood);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color.fromARGB(255, 0, 191, 216)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  mood.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  mood.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.grey[700],
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: widget.isNewVideo
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, _getResult());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C2C2C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                    : widget.showDeleteButton
                    ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context, {'delete': true});
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
