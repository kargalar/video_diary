import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/diary/data/diary_repository.dart';
import '../../../../features/settings/viewmodel/settings_view_model.dart';
import '../../../../services/export_import_service.dart';

class ExportImportDialog extends StatefulWidget {
  final VoidCallback onDataImported;

  const ExportImportDialog({super.key, required this.onDataImported});

  @override
  State<ExportImportDialog> createState() => _ExportImportDialogState();
}

class _ExportImportDialogState extends State<ExportImportDialog> {
  final _service = ExportImportService();
  final _diaryRepo = DiaryRepository();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export & Import'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Export saves all your video data (title, description, rating, mood, etc.) to a JSON file. Use Import to load data from another device.', style: TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text('⚠️ Note: Export only saves metadata. You must manually transfer the actual video files to the new device.', style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF1976D2))),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text('📁 During Import: You will be asked to select the folder where your video files are located on this device.', style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFF57F17))),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              '🔴 Warning: Importing will replace ALL existing data. Your current videos will be deleted. This cannot be undone!',
              style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFD32F2F), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(onPressed: _handleExport, icon: const Icon(Icons.download), label: const Text('Download Export')),
                const SizedBox(height: 12),
                ElevatedButton.icon(onPressed: _handleImport, icon: const Icon(Icons.upload), label: const Text('Upload Import')),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _handleClearAll,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear All Videos'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
                ),
              ],
            ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }

  Future<void> _handleExport() async {
    try {
      setState(() => _isLoading = true);

      // Generate filename
      final timestamp = DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.')[0];
      final fileName = 'video_diary_export_$timestamp.json';

      // Ask user to select where to save the file (choose directory)
      final selectedDir = await getDirectoryPath();

      // User must select a location - if cancelled, stop here
      if (selectedDir == null || selectedDir.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export cancelled'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
        }
        return;
      }

      // Full path: directory + filename
      final fullPath = '$selectedDir/$fileName';

      // Export to the selected location
      final exportPath = await _service.exportData(fullPath);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Export successful: $exportPath'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      // Show error if export fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleImport() async {
    try {
      // Step 1: Ask user to select JSON file
      const typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file == null) return;

      // Step 2: Show warning dialog FIRST
      if (!mounted) return;
      final continueImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Delete All Current Data?'),
          content: const Text(
            'Importing will DELETE ALL your current video data.\n\n'
            'Your current videos:\n'
            '• All video metadata\n'
            '• Titles, descriptions, ratings\n'
            '• Moods and all other data\n\n'
            'will be permanently deleted.\n\n'
            'If you want to continue, select the folder where your old videos are located. Then they will be copied to the storage folder.',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Continue & Select Folder', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (continueImport != true) return;

      // Step 3: Ask user to select video folder (old videos location)
      if (!mounted) return;
      final videoDirPath = await getDirectoryPath();

      if (videoDirPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import cancelled: Video directory not selected'), backgroundColor: Colors.orange));
        }
        return;
      }

      // Step 4: Perform import
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final jsonFile = File(file.path);
      final importedCount = await _service.importData(jsonFile, videoDirPath, replaceExisting: true);

      if (mounted) {
        // Save the selected video directory as storage directory
        if (!mounted) return;
        try {
          final settingsVm = context.read<SettingsViewModel>();
          settingsVm.setStorageDirectory(videoDirPath);
        } catch (e) {
          debugPrint('⚠️ Failed to save storage directory: $e');
        }

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ All old data deleted! $importedCount new videos imported'), backgroundColor: Colors.green, duration: const Duration(seconds: 4)));
        widget.onDataImported();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleClearAll() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear All Videos?'),
        content: const Text(
          'This will permanently DELETE ALL your videos and data.\n\n'
          'This action CANNOT be undone!\n\n'
          'Are you sure?',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      await _diaryRepo.clear();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ All videos cleared!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        widget.onDataImported();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
