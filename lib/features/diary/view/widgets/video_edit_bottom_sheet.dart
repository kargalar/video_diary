import 'package:flutter/material.dart';

import '../../model/mood.dart';

class VideoEditBottomSheet extends StatefulWidget {
  final String currentTitle;
  final int? currentRating;
  final List<Mood> currentMoods;
  final bool showCloseButton;

  const VideoEditBottomSheet({super.key, required this.currentTitle, this.currentRating, required this.currentMoods, this.showCloseButton = true});

  @override
  State<VideoEditBottomSheet> createState() => _VideoEditBottomSheetState();
}

class _VideoEditBottomSheetState extends State<VideoEditBottomSheet> {
  late TextEditingController _titleController;
  late int _rating;
  late Set<Mood> _selectedMoods;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _rating = widget.currentRating ?? 0;
    _selectedMoods = widget.currentMoods.toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Edit Video', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ),
                if (widget.showCloseButton) IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                  Text('Title', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                  const SizedBox(height: 8),
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
                        borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Rating
                  Text('Rating', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(starValue <= _rating ? Icons.star : Icons.star_border, color: starValue <= _rating ? Colors.amber : Colors.grey[400]),
                        onPressed: () => setState(() => _rating = starValue),
                      );
                    }),
                  ),
                  if (_rating > 0)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _rating = 0),
                        child: Text('Clear Rating', style: TextStyle(color: Colors.grey[600])),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Moods
                  Row(
                    children: [
                      Expanded(
                        child: Text('Mood', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                      ),
                      if (_selectedMoods.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _selectedMoods.clear()),
                          child: Text('Clear', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Mood.values.map((mood) {
                      final isSelected = _selectedMoods.contains(mood);
                      return FilterChip(
                        label: Text(mood.displayText),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedMoods.add(mood);
                            } else {
                              _selectedMoods.remove(mood);
                            }
                          });
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: const Color(0xFF2C2C2C).withAlpha(20),
                        checkmarkColor: const Color(0xFF2C2C2C),
                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[700], fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[300]!),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Action buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: widget.showCloseButton
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {'title': _titleController.text.trim(), 'rating': _rating == 0 ? null : _rating, 'moods': _selectedMoods.toList()});
                        },
                        child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context), // Cancel - returns null
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: theme.dividerColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, {'title': _titleController.text.trim(), 'rating': _rating == 0 ? null : _rating, 'moods': _selectedMoods.toList()});
                            },
                            child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
