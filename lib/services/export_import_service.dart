import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_diary/features/settings/data/settings_repository.dart';
import 'package:video_diary/features/settings/model/settings.dart';

import '../features/diary/data/day_data_repository.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/diary/data/mood_repository.dart';
import '../features/diary/model/diary_entry.dart';
import '../features/diary/model/mood.dart';

class ExportImportService {
  static const int _exportVersion = 2;
  static const String _metaPath = 'export.json';
  static const String _videosDir = 'videos';
  static const String _thumbsDir = 'thumbnails';

  // SharedPreferences keys treated as part of app data.
  static const String _prefCameraLensKey = 'preferred_camera_lens';
  static const String _prefRecordedVideoCountKey = 'recorded_video_count';
  static const String _prefReviewCompletedKey = 'review_completed';

  final DiaryRepository _diaryRepo = DiaryRepository();
  final DayDataRepository _dayRepo = DayDataRepository();
  final MoodRepository _moodRepo = MoodRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  /// Export ALL data as a ZIP: metadata + videos + thumbnails + settings + day data.
  /// [savePath] should be a file path ending with `.zip`.
  /// Returns created zip file path.
  Future<String> exportData(String savePath) async {
    try {
      debugPrint('📦 Exporting full backup (zip)...');

      final zipFile = File(savePath);
      await zipFile.parent.create(recursive: true);
      if (await zipFile.exists()) await zipFile.delete();

      final entries = await _diaryRepo.load();

      await _dayRepo.init();
      final dayData = await _dayRepo.getAll();

      final SettingsModel settings = await _settingsRepo.load();
      final moods = await _moodRepo.load();

      final prefs = await SharedPreferences.getInstance();
      final prefsData = <String, dynamic>{_prefCameraLensKey: prefs.getString(_prefCameraLensKey), _prefRecordedVideoCountKey: prefs.getInt(_prefRecordedVideoCountKey), _prefReviewCompletedKey: prefs.getBool(_prefReviewCompletedKey)};

      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);

      final exportedEntries = <Map<String, dynamic>>[];

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];

        String? relVideoPath;
        if (entry.path.isNotEmpty) {
          final src = File(entry.path);
          if (await src.exists()) {
            final originalName = src.uri.pathSegments.last;
            relVideoPath = '$_videosDir/$originalName';
            await encoder.addFile(src, relVideoPath);
          }
        }

        String? relThumbPath;
        final thumb = entry.thumbnailPath;
        if (thumb != null && thumb.isNotEmpty) {
          final src = File(thumb);
          if (await src.exists()) {
            final originalName = src.uri.pathSegments.last;
            relThumbPath = '$_thumbsDir/$originalName';
            await encoder.addFile(src, relThumbPath);
          }
        }

        final json = Map<String, dynamic>.from(entry.toJson());
        if (relVideoPath != null) json['path'] = relVideoPath;
        if (relThumbPath != null) json['thumbnailPath'] = relThumbPath;
        exportedEntries.add(json);
      }

      final exportMeta = <String, dynamic>{
        'version': _exportVersion,
        'format': 'zip',
        'exportedAt': DateTime.now().toIso8601String(),
        'totalVideos': entries.length,
        'videos': exportedEntries,
        'dayData': {for (final e in dayData.entries) e.key: e.value.toJson()},
        'moodCatalog': moods.map((mood) => mood.toJson()).toList(),
        'settings': settings.toJson(),
        'prefs': prefsData,
      };

      final metaBytes = utf8.encode(jsonEncode(exportMeta));
      encoder.addArchiveFile(ArchiveFile(_metaPath, metaBytes.length, metaBytes));
      await encoder.close();

      debugPrint('✅ Export successful: ${zipFile.path}');
      return zipFile.path;
    } catch (e) {
      debugPrint('❌ Export error: $e');
      rethrow;
    }
  }

  /// Import ALL data from a ZIP backup.
  /// [restoreToDirectory] is the base directory where videos/thumbnails will be extracted.
  /// If [replaceExisting] is true, replaces all existing data with imported data.
  /// Returns: number of imported videos.
  Future<int> importData(File zipFile, String restoreToDirectory, {bool replaceExisting = true}) async {
    try {
      debugPrint('📥 Importing full backup (zip) from: ${zipFile.path}');
      debugPrint('📥 Restoring files to: $restoreToDirectory');
      debugPrint('📥 Replace existing data: $replaceExisting');

      if (!await zipFile.exists()) {
        throw Exception('Backup file not found: ${zipFile.path}');
      }

      final restoreDir = Directory(restoreToDirectory);
      await restoreDir.create(recursive: true);

      final input = InputFileStream(zipFile.path);
      late final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } finally {
        await input.close();
      }

      final metaArchiveFile = archive.files.firstWhere((f) => f.isFile && f.name == _metaPath, orElse: () => throw Exception('Invalid backup: missing $_metaPath'));

      final metaString = utf8.decode(metaArchiveFile.content as List<int>);
      final meta = jsonDecode(metaString) as Map<String, dynamic>;

      final version = meta['version'] as int?;
      if (version != _exportVersion) {
        throw Exception('Unsupported backup version: $version');
      }

      // Extract files first.
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (f.name == _metaPath) continue;

        final outPath = _resolveInside(restoreDir.path, f.name);
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);

        final out = OutputFileStream(outFile.path);
        try {
          f.writeContent(out);
        } finally {
          await out.close();
        }
      }

      // Import diary entries.
      final videosList = (meta['videos'] as List<dynamic>?) ?? [];
      final importedEntries = videosList.map((e) {
        final entry = DiaryEntry.fromJson(Map<String, dynamic>.from(e as Map));

        final mappedVideoPath = entry.path.isEmpty ? '' : _resolveInside(restoreDir.path, entry.path);
        final thumb = entry.thumbnailPath;
        final mappedThumbPath = (thumb == null || thumb.isEmpty) ? null : _resolveInside(restoreDir.path, thumb);

        return DiaryEntry(path: mappedVideoPath, date: entry.date, thumbnailPath: mappedThumbPath, durationMs: entry.durationMs, fileBytes: entry.fileBytes, title: entry.title, description: entry.description, rating: entry.rating, moods: entry.moods);
      }).toList();

      importedEntries.sort((a, b) => b.date.compareTo(a.date));

      final currentMoodCatalog = await _moodRepo.load();
      final importedMoodCatalog = (meta['moodCatalog'] as List<dynamic>?)?.map(Mood.fromDynamic).whereType<Mood>().toList() ?? <Mood>[];

      final mergedMoodCatalog = <Mood>[
        if (!replaceExisting) ...currentMoodCatalog,
        ...importedMoodCatalog,
        for (final entry in importedEntries)
          for (final mood in entry.moods ?? const <Mood>[])
            if (![...(!replaceExisting ? currentMoodCatalog : const <Mood>[]), ...importedMoodCatalog].any((existing) => existing.id == mood.id)) mood,
      ];

      if (mergedMoodCatalog.isNotEmpty) {
        await _moodRepo.save(mergedMoodCatalog);
      }

      if (replaceExisting) {
        await _diaryRepo.save(importedEntries);
      } else {
        final currentEntries = await _diaryRepo.load();
        final existingPaths = currentEntries.map((e) => e.path).toSet();
        final toAdd = importedEntries.where((e) => !existingPaths.contains(e.path)).toList();
        final combined = [...currentEntries, ...toAdd];
        combined.sort((a, b) => b.date.compareTo(a.date));
        await _diaryRepo.save(combined);
      }

      // Import day data.
      final dayDataRaw = meta['dayData'];
      if (dayDataRaw is Map) {
        await _dayRepo.init();
        final box = Hive.box('day_data');
        await box.clear();
        for (final entry in dayDataRaw.entries) {
          final k = entry.key.toString();
          final v = entry.value;
          if (v is Map) {
            await box.put(k, Map<String, dynamic>.from(v));
          }
        }
      }

      // Import settings. Don't override storageDirectory so it uses internal defaults.
      final settingsRaw = meta['settings'];
      if (settingsRaw is Map) {
        final importedSettings = SettingsModel.fromJson(Map<String, dynamic>.from(settingsRaw));
        final patched = importedSettings.copyWith(storageDirectory: null);
        await _settingsRepo.save(patched);
      }

      // Import selected shared prefs.
      final prefsRaw = meta['prefs'];
      if (prefsRaw is Map) {
        final prefs = await SharedPreferences.getInstance();
        final m = Map<String, dynamic>.from(prefsRaw);

        final lens = m[_prefCameraLensKey];
        if (lens is String) {
          await prefs.setString(_prefCameraLensKey, lens);
        }
        final cnt = m[_prefRecordedVideoCountKey];
        if (cnt is int) {
          await prefs.setInt(_prefRecordedVideoCountKey, cnt);
        }
        final completed = m[_prefReviewCompletedKey];
        if (completed is bool) {
          await prefs.setBool(_prefReviewCompletedKey, completed);
        }
      }

      debugPrint('✅ Import successful: ${importedEntries.length} videos');
      return importedEntries.length;
    } catch (e) {
      debugPrint('❌ Import error: $e');
      rethrow;
    }
  }

  /// Legacy helper, kept for backwards compatibility.
  /// For ZIP backups this returns false.
  bool validateJsonFormat(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['version'] as int?;
      final videos = data['videos'] as List<dynamic>?;
      return version == 1 && videos != null && videos.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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

  /// Resolves [relative] inside [base] and rejects path traversal / absolute paths.
  String _resolveInside(String base, String relative) {
    // Normalize to forward slashes for validation.
    final r = relative.replaceAll('\\', '/');
    if (r.isEmpty) throw Exception('Invalid path in backup (empty)');
    if (r.startsWith('/') || r.startsWith('~/')) {
      throw Exception('Invalid path in backup (absolute): $relative');
    }
    // Windows drive letters like C:/
    if (r.length >= 2 && r[1] == ':') {
      throw Exception('Invalid path in backup (drive): $relative');
    }

    final parts = r.split('/');
    for (final p in parts) {
      if (p.isEmpty) continue;
      if (p == '.' || p == '..') {
        throw Exception('Invalid path in backup (traversal): $relative');
      }
    }

    final sep = Platform.pathSeparator;
    final clean = parts.where((p) => p.isNotEmpty).join(sep);
    final b = base.endsWith(sep) ? base.substring(0, base.length - 1) : base;
    return '$b$sep$clean';
  }
}
