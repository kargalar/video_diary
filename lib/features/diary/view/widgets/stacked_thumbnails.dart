import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class StackedThumbnails extends StatelessWidget {
  final List<dynamic> entries;

  const StackedThumbnails({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final thumbsInfo = entries.take(3).where((e) => e.thumbnailPath != null).map((e) => {'path': e.thumbnailPath as String, 'lensDirection': e.lensDirection as String?}).toList();

    if (thumbsInfo.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.videocam_outlined, size: 48, color: Colors.grey[400]),
      );
    }

    Widget buildThumb(Map<String, dynamic> info) {
      final img = Image.file(File(info['path'] as String), fit: BoxFit.cover);
      if (info['lensDirection'] == 'front') {
        return Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: img);
      }
      return img;
    }

    return Stack(
      children: [
        // Main thumbnail (full)
        Positioned.fill(child: buildThumb(thumbsInfo[0])),
        // Second thumbnail (if exists) - small overlay at bottom right
        if (thumbsInfo.length > 1)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: buildThumb(thumbsInfo[1])),
            ),
          ),
        // Third thumbnail (if exists) - small overlay next to second
        if (thumbsInfo.length > 2)
          Positioned(
            bottom: 8,
            right: 76,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: buildThumb(thumbsInfo[2])),
            ),
          ),
      ],
    );
  }
}
