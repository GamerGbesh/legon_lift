// Owner: WS1. Backup and restore (SPEC 4.12, 9.2).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../data/repositories/repositories.dart';
import '../../widgets/big_button.dart';
import '../../widgets/section_header.dart';
import 'backup_files.dart';
import 'data_actions.dart';

final DateFormat _when = DateFormat('EEE d MMM yyyy, HH:mm');

/// Export (share sheet or "Save to device"), import (preview, then Merge or Replace, with Undo)
/// and the weekly automatic backups.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, @visibleForTesting this.files = const PlatformBackupFiles()});

  /// File access; tests pass a fake.
  final BackupFiles files;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final DataActions _actions = DataActions.of(context);
  bool _busy = false;
  DateTime? _lastExport, _lastAuto;
  List<AutoBackupFile> _autoFiles = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final (lastExport, lastAuto, files) =
        await (_actions.lastExport(), _actions.autoBackup.lastRun(), _actions.autoBackup.list()).wait;
    if (!mounted) return;
    setState(() {
      _lastExport = lastExport;
      _lastAuto = lastAuto;
      _autoFiles = files;
    });
  }

  void _snack(String message, {SnackBarAction? action, Duration duration = const Duration(seconds: 4)}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action, duration: duration));
  }

  /// Runs [job] with the buttons disabled and a progress bar. Returns its result, or null after
  /// showing [failure] (or the backup's own plain-language error) when it throws.
  Future<T?> _run<T>(Future<T> Function() job, {required String failure}) async {
    setState(() => _busy = true);
    try {
      return await job();
    } on BackupFormatException catch (e) {
      if (mounted) _snack(e.message);
      return null;
    } on Object catch (e, st) {
      debugPrint('$failure: $e\n$st');
      if (mounted) _snack(failure);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export({required bool share}) async {
    if (_busy) return;
    final done = await _run(() async {
      final (bytes, name) = await _actions.export();
      final ok = share ? await widget.files.share(bytes, name) : await widget.files.saveToDevice(bytes, name);
      if (ok) await _actions.markExported();
      return ok;
    }, failure: share ? 'Could not share the backup. Try "Save to device".' : 'Could not save the backup.');
    if (done != true || !mounted) return;
    _snack(share ? 'Backup shared.' : 'Backup saved.');
    await _refresh();
  }

  Future<void> _importFromFile() async {
    if (_busy) return;
    // The system picker is the user's to finish; no progress bar while it is open.
    final Uint8List? bytes;
    try {
      bytes = await widget.files.pick();
    } on Object catch (e, st) {
      debugPrint('Could not open the file picker: $e\n$st');
      if (mounted) _snack('Could not open your files.');
      return;
    }
    if (bytes != null && mounted) await _previewAndImport(bytes);
  }

  Future<void> _importAuto(AutoBackupFile f) async {
    if (_busy) return;
    final bytes = await _run(f.read, failure: 'Could not read that backup.');
    if (bytes != null && mounted) await _previewAndImport(bytes);
  }

  /// Preview (busy) -> the user's choice in a sheet (not busy) -> restore (busy) -> Undo snackbar.
  Future<void> _previewAndImport(Uint8List bytes) async {
    final preview = await _run(() => _actions.backup.preview(bytes), failure: 'Could not read that file.');
    if (preview == null || !mounted) return;
    final replace = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ImportSheet(preview: preview),
    );
    if (replace == null || !mounted) return;
    final snapshot = await _run(
      () => _actions.restore(bytes, replace: replace),
      failure: 'Could not restore the backup. Nothing was changed.',
    );
    if (snapshot == null || !mounted) return;
    _snack(
      replace ? 'Backup restored. Your data was replaced.' : 'Backup merged with your data.',
      duration: Motion.snackUndo,
      action: SnackBarAction(label: 'Undo', onPressed: () => unawaited(_undo(snapshot))),
    );
    await _refresh();
  }

  Future<void> _undo(Uint8List snapshot) async {
    try {
      await _actions.undo(snapshot);
      if (mounted) _snack('Restore undone.');
    } on Object catch (e, st) {
      debugPrint('Undo restore failed: $e\n$st');
      if (mounted) _snack('Could not undo the restore.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final muted = AppText.body.copyWith(color: t.muted);
    final lastExport = _lastExport;
    final lastAuto = _lastAuto;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
        children: [
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: Space.l),
          Text(
            'Everything you log stays on this phone. Save a copy now and then somewhere safe, '
            'like Google Drive or a WhatsApp chat with yourself, so a lost or broken phone '
            'does not cost you your progress.',
            style: AppText.body.copyWith(color: t.onSurface),
          ),
          const SectionHeader('Save a copy'),
          Text(
            lastExport == null ? 'You have not saved a copy yet.' : 'Last copy: ${_when.format(lastExport)}',
            style: muted,
          ),
          const SizedBox(height: Space.m),
          BigButton(
            label: 'Share backup',
            icon: Icons.share,
            onPressed: _busy ? null : () => unawaited(_export(share: true)),
          ),
          const SizedBox(height: Space.m),
          BigButton(
            label: 'Save to device',
            icon: Icons.save_alt,
            kind: BigButtonKind.secondary,
            height: Sizes.heroButton,
            onPressed: _busy ? null : () => unawaited(_export(share: false)),
          ),
          const SectionHeader('Restore'),
          Text(
            'Open a Legon Lift backup file. You will see what is inside before anything changes.',
            style: muted,
          ),
          const SizedBox(height: Space.m),
          BigButton(
            label: 'Restore from a file',
            icon: Icons.restore,
            kind: BigButtonKind.secondary,
            height: Sizes.heroButton,
            onPressed: _busy ? null : () => unawaited(_importFromFile()),
          ),
          const SectionHeader('Automatic backups'),
          Text(
            'A copy is saved on this phone once a week and the last '
            '${SqfliteBackupService.keepAutoBackups} are kept. '
            '${lastAuto == null ? 'No weekly copy yet.' : 'Last weekly copy: ${_when.format(lastAuto)}.'} '
            'These copies are deleted if you uninstall the app, so also save one elsewhere.',
            style: muted,
          ),
          const SizedBox(height: Space.s),
          for (final f in _autoFiles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: Sizes.minTap,
              leading: Icon(Icons.history, color: t.muted),
              title: Text(_when.format(f.modified), style: AppText.tabular(AppText.body).copyWith(color: t.onSurface)),
              subtitle: Text(_size(f.sizeBytes), style: AppText.label.copyWith(color: t.muted)),
              trailing: const Icon(Icons.chevron_right),
              enabled: !_busy,
              onTap: () => unawaited(_importAuto(f)),
            ),
        ],
      ),
    );
  }

  static String _size(int bytes) =>
      bytes < 1024 * 1024 ? '${(bytes / 1024).ceil()} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// What the backup holds and the two ways to use it. Pops true for Replace, false for Merge.
class _ImportSheet extends StatelessWidget {
  const _ImportSheet({required this.preview});

  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = preview;
    String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This backup holds', style: AppText.headline.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.s),
          Text('Saved ${_when.format(p.exportedAt)}', style: AppText.body.copyWith(color: t.muted)),
          const SizedBox(height: Space.l),
          for (final line in [
            n(p.sessions, 'workout', 'workouts'),
            n(p.sets, 'logged set', 'logged sets'),
            n(p.bodyEntries, 'body weight entry', 'body weight entries'),
            n(p.nutritionDays, 'food day', 'food days'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Text(line, style: AppText.tabular(AppText.body).copyWith(color: t.onSurface, fontSize: 18)),
            ),
          for (final w in p.warnings)
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: t.warning, size: 20),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(w, style: AppText.label.copyWith(color: t.onSurface))),
                ],
              ),
            ),
          const SizedBox(height: Space.xl),
          Text(
            'Merge adds what is missing and keeps everything you have now. '
            'Replace swaps all your data for this backup.',
            style: AppText.label.copyWith(color: t.muted),
          ),
          const SizedBox(height: Space.l),
          BigButton(label: 'Merge with my data', icon: Icons.merge, onPressed: () => Navigator.of(context).pop(false)),
          const SizedBox(height: Space.l),
          BigButton(
            label: 'Replace all my data',
            icon: Icons.swap_horiz,
            kind: BigButtonKind.destructive,
            height: Sizes.minTap,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
