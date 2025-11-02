import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  // Let user pick a folder; returns null if user cancels the dialog
  Future<String?> pickDirectory({String? initialDirectory}) async {
    // Android 11+ may require MANAGE_EXTERNAL_STORAGE for arbitrary directories.
    // We attempt SAF via file_selector. If not available, return app docs.
    try {
      if (Platform.isAndroid) {
        // request camera + notifications outside
        final status = await Permission.storage.request();
        if (!status.isGranted && !status.isLimited) {
          // continue but may fail to write in external dirs
        }
      }
    } catch (_) {}

    final dir = await getDirectoryPath(initialDirectory: initialDirectory);
    if (dir != null) return dir;
    // User cancelled the dialog or directory picker not available
    return null;
  }

  Future<Directory> ensureDiaryFolder(String baseDir) async {
    final d = Directory(baseDir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }
}
