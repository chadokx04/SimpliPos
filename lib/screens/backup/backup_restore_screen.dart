import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../navigation/restart_widget.dart';
import '../../providers/auto_backup_provider.dart';
import '../../providers/pos_provider.dart';
import '../../utils/backup_service.dart';
import '../../utils/constants.dart';
import '../../widgets/auto_backup_interval_sheet.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<BackupInfo>> _future;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = BackupService.listBackups();
    // The auto backup timer keeps running (and bumping runCount) even while
    // this screen isn't the one triggering it — refresh the list whenever
    // it does, so the Auto Backup tab doesn't need a manual pull-to-refresh.
    context.read<AutoBackupProvider>().addListener(_refresh);
  }

  @override
  void dispose() {
    context.read<AutoBackupProvider>().removeListener(_refresh);
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = BackupService.listBackups();
    });
  }

  Future<void> _createBackup() async {
    setState(() => _isWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.createBackup();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Backup created')));
      _refresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _confirmRestore(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This will overwrite all current products, categories, sales '
          'history, and photos with the contents of "${backup.fileName}". '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.restoreBackup(backup.path);
      if (!mounted) return;
      // The persisted POS cart may reference products that no longer
      // exist (or mean something different) post-restore, same reasoning
      // as the drawer's "Reset" — clear it before restarting.
      context.read<PosProvider>().clearCart();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text(
            'The app needs to restart so every screen reloads the '
            'restored data.',
          ),
          actions: [
            FilledButton(
              onPressed: () => RestartWidget.restartApp(context),
              child: const Text('Restart Now'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Hands the zip to the OS share sheet, so it can be sent elsewhere
  /// (email, Bluetooth, chat apps, cloud drives, etc.) — distinct from
  /// [_downloadBackup], which writes straight into a chosen local folder.
  Future<void> _shareBackup(BackupInfo backup) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(backup.path)], subject: backup.fileName),
    );
  }

  /// Opens the OS's native "Save As" document picker — Downloads is a
  /// first-class location there, unlike the app-chooser share sheet (which
  /// on some devices/Android skins doesn't surface a direct save-to-
  /// Downloads option at all). This is a real file write via Storage
  /// Access Framework, not a share action.
  Future<void> _downloadBackup(BackupInfo backup) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FileSaver.instance.saveAs(
        name: p.basenameWithoutExtension(backup.fileName),
        filePath: backup.path,
        fileExtension: 'zip',
        mimeType: MimeType.zip,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _uploadBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final pickedPath = picked?.path;
    if (pickedPath == null || !mounted) return;

    final source = File(pickedPath);
    final fileName = BackupService.normalizeFileName(
      pickedPath.split(Platform.pathSeparator).last,
    );

    if (await BackupService.backupFileExists(fileName)) {
      if (!mounted) return;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overwrite existing backup?'),
          content: Text(
            'A backup named "$fileName" is already in the list. '
            'Overwrite it with the uploaded file?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (overwrite != true || !mounted) return;
    }

    if (!mounted) return;
    setState(() => _isWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.importBackup(source);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Backup uploaded')));
      _refresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _confirmDelete(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this backup?'),
        content: Text('Delete "${backup.fileName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await BackupService.deleteBackup(backup.path);
    if (mounted) _refresh();
  }

  Future<void> _pickInterval(AutoBackupProvider autoBackup) async {
    final seconds = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AutoBackupIntervalSheet(initialSeconds: autoBackup.intervalSeconds),
    );
    if (seconds != null) await autoBackup.setIntervalSeconds(seconds);
  }

  String _formatInterval(int seconds) {
    if (seconds >= 60 && seconds % 60 == 0) {
      final minutes = seconds ~/ 60;
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    }
    return '$seconds second${seconds == 1 ? '' : 's'}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildBackupList(List<BackupInfo> backups, DateFormat dateFormat, String emptyText) {
    if (backups.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: backups.length,
      itemBuilder: (context, index) {
        final backup = backups[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(dateFormat.format(backup.createdAt)),
                subtitle: Text(_formatSize(backup.sizeBytes)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share',
                      onPressed: _isWorking ? null : () => _shareBackup(backup),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Save to device',
                      onPressed: _isWorking ? null : () => _downloadBackup(backup),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: _isWorking ? null : () => _confirmDelete(backup),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isWorking ? null : () => _confirmRestore(backup),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jms();
    final autoBackup = context.watch<AutoBackupProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Auto Backup'),
            subtitle: Text(
              'Back up automatically every ${_formatInterval(autoBackup.intervalSeconds)}, '
              'keeping the last $kAutoBackupMaxCount',
            ),
            value: autoBackup.enabled,
            onChanged: (value) => autoBackup.setEnabled(value),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto Backup Interval'),
            subtitle: Text(_formatInterval(autoBackup.intervalSeconds)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickInterval(autoBackup),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isWorking ? null : _createBackup,
                    icon: _isWorking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.backup_outlined),
                    label: const Text('Create Backup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isWorking ? null : _uploadBackup,
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<BackupInfo>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final backups = snapshot.data!;
                final manualBackups = backups.where((b) => !b.isAuto).toList();
                final autoBackups = backups.where((b) => b.isAuto).toList();
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBackupList(manualBackups, dateFormat, 'No backups yet'),
                    _buildBackupList(
                      autoBackups,
                      dateFormat,
                      'No auto backups yet — turn on Auto Backup above',
                    ),
                  ],
                );
              },
            ),
          ),
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Manual'),
                  Tab(text: 'Auto Backup'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
