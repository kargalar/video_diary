import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../features/diary/data/diary_repository.dart';
import '../features/diary/model/diary_entry.dart';

class ExportImportService {
  final DiaryRepository _diaryRepo = DiaryRepository();

  /// Get the storage folder for videos
  Future<Directory> _getStorageDirectory() async {
    // For Android: /storage/emulated/0/Documents/VideoDiary
    // For iOS: Documents directory
    // For other platforms: application documents directory
    try {
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Documents/VideoDiary');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final storageDir = Directory('${dir.path}/VideoDiary');
        if (!await storageDir.exists()) {
          await storageDir.create(recursive: true);
        }
        return storageDir;
      }
    } catch (e) {
      debugPrint('⚠️ Could not get storage directory: $e');
      final dir = await getApplicationDocumentsDirectory();
      return dir;
    }
  }

  /// Export all video data as JSON and save to user-selected location
  /// Returns: File path
  Future<String> exportData(String savePath) async {
    try {
      debugPrint('📤 Exporting diary data...');

      // Load data
      final entries = await _diaryRepo.load();
      debugPrint('📤 Loaded ${entries.length} entries');

      // Convert to JSON format
      final exportData = {'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'totalVideos': entries.length, 'videos': entries.map((e) => e.toJson()).toList()};

      final jsonString = jsonEncode(exportData);

      // Create file at specified path
      final file = File(savePath);

      // Ensure parent directory exists
      await file.parent.create(recursive: true);

      await file.writeAsString(jsonString);
      debugPrint('✅ Export successful: ${file.path}');

      return file.path;
    } catch (e) {
      debugPrint('❌ Export error: $e');
      rethrow;
    }
  }

  /// Import video data from the given JSON file
  /// videosSourcePath: Base directory where video files are located on this device
  /// replaceExisting: If true, replaces all existing data with imported data
  /// Returns: Number of imported videos
  Future<int> importData(File jsonFile, String videosSourcePath, {bool replaceExisting = true}) async {
    try {
      debugPrint('📥 Importing diary data from: ${jsonFile.path}');
      debugPrint('📥 Using video source path: $videosSourcePath');
      debugPrint('📥 Replace existing data: $replaceExisting');

      // Read file
      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Version check
      final version = data['version'] as int?;
      if (version != 1) {
        throw Exception('Unsupported export version: $version');
      }

      // Parse videos list
      final videosList = (data['videos'] as List<dynamic>?) ?? [];
      debugPrint('📥 Found ${videosList.length} videos to import');

      final newEntries = videosList.map((e) {
        final entry = DiaryEntry.fromJson(Map<String, dynamic>.from(e as Map));
        // Update video paths to use the new device's video source path
        if (entry.path.isNotEmpty) {
          // Extract just the filename from old path (handle both / and \ separators)
          final videoFileName = entry.path.split('/').last.split('\\').last;
          final newPath = '$videosSourcePath/$videoFileName';
          debugPrint('📥 Mapping video: ${entry.path} -> $newPath');
          return DiaryEntry(path: newPath, date: entry.date, thumbnailPath: entry.thumbnailPath, durationMs: entry.durationMs, fileBytes: entry.fileBytes, title: entry.title, description: entry.description, rating: entry.rating, moods: entry.moods);
        }
        return entry;
      }).toList();

      if (replaceExisting) {
        // Get storage directory for saving videos
        final storageDir = await _getStorageDirectory();
        debugPrint('📥 Storage directory: ${storageDir.path}');

        // Copy videos from source to storage directory and update paths
        final finalEntries = <DiaryEntry>[];
        for (var entry in newEntries) {
          if (entry.path.isNotEmpty) {
            try {
              final sourceFile = File(entry.path);
              if (await sourceFile.exists()) {
                final fileName = entry.path.split('/').last.split('\\').last;
                final destPath = '${storageDir.path}/$fileName';
                await sourceFile.copy(destPath);
                debugPrint('📥 Copied video: ${entry.path} -> $destPath');

                // Create new entry with storage path
                finalEntries.add(DiaryEntry(path: destPath, date: entry.date, thumbnailPath: entry.thumbnailPath, durationMs: entry.durationMs, fileBytes: entry.fileBytes, title: entry.title, description: entry.description, rating: entry.rating, moods: entry.moods));
              } else {
                debugPrint('⚠️ Source video not found: ${entry.path}');
                // Still add the entry, but path might not exist
                finalEntries.add(entry);
              }
            } catch (e) {
              debugPrint('⚠️ Failed to copy video: $e');
              // Still add the entry on error
              finalEntries.add(entry);
            }
          } else {
            finalEntries.add(entry);
          }
        }

        // Replace all existing data with imported data
        debugPrint('📥 Replacing all existing data with ${finalEntries.length} imported entries');
        final sortedEntries = [...finalEntries];
        sortedEntries.sort((a, b) => b.date.compareTo(a.date));
        await _diaryRepo.save(sortedEntries);
        debugPrint('✅ Import successful: All data replaced with ${finalEntries.length} videos');
        return finalEntries.length;
      } else {
        // Merge with existing data (old behavior)
        final currentEntries = await _diaryRepo.load();
        final existingPaths = currentEntries.map((e) => e.path).toSet();
        final entriesToAdd = newEntries.where((e) => !existingPaths.contains(e.path)).toList();

        debugPrint('📥 ${entriesToAdd.length} new entries to add (${videosList.length - entriesToAdd.length} duplicates skipped)');

        final combinedEntries = [...currentEntries, ...entriesToAdd];
        combinedEntries.sort((a, b) => b.date.compareTo(a.date));
        await _diaryRepo.save(combinedEntries);

        debugPrint('✅ Import successful: ${entriesToAdd.length} new videos added');
        return entriesToAdd.length;
      }
    } catch (e) {
      debugPrint('❌ Import error: $e');
      rethrow;
    }
  }

  /// Share export file (to be implemented in future version)
  Future<void> shareExport(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('Export file not found: $filePath');
      }
      debugPrint('✅ Export file ready for sharing: $filePath');
      // TODO: Use shareXFiles when SharePlus version is updated
    } catch (e) {
      debugPrint('❌ Share error: $e');
      rethrow;
    }
  }

  /// Validate given JSON string
  bool validateJsonFormat(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['version'] as int?;
      final videos = data['videos'] as List<dynamic>?;

      return version == 1 && videos != null && videos.isNotEmpty;
    } catch (e) {
      debugPrint('❌ JSON validation error: $e');
      return false;
    }
  }

  /// Get information about export and import operations
  Future<Map<String, dynamic>> getExportInfo() async {
    try {
      final entries = await _diaryRepo.load();

      int totalDurationMs = 0;
      int totalFileBytes = 0;

      for (final entry in entries) {
        if (entry.durationMs != null) totalDurationMs += entry.durationMs!;
        if (entry.fileBytes != null) totalFileBytes += entry.fileBytes!;
      }

      return {'totalVideos': entries.length, 'totalDurationSec': totalDurationMs ~/ 1000, 'totalSizeBytes': totalFileBytes, 'exportTimestamp': DateTime.now().toIso8601String()};
    } catch (e) {
      debugPrint('❌ Error getting export info: $e');
      return {};
    }
  }
}
