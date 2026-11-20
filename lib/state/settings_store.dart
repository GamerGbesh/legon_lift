import 'package:flutter/foundation.dart';

import '../data/models/models.dart';
import '../data/repositories/settings_repository.dart';

/// App settings (SPEC 7.4). Owner: WS1.
///
/// Every change goes through [update], which writes to SQLite before notifying, so a setting
/// changed just before the app is killed is never lost.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._repository, {required AppSettings initial}) : _settings = initial;

  /// Reads the saved settings (or first-run defaults) and returns a ready store.
  static Future<SettingsStore> load(SettingsRepository repository) async =>
      SettingsStore(repository, initial: await repository.loadSettings());

  final SettingsRepository _repository;
  AppSettings _settings;

  AppSettings get settings => _settings;

  /// Saves [s] and notifies listeners. Saving the current value is a no-op.
  Future<void> update(AppSettings s) async {
    if (s == _settings) return;
    await _repository.saveSettings(s);
    _settings = s;
    notifyListeners();
  }

  /// Re-reads the saved settings (after a backup restore or a reset).
  Future<void> reload() async {
    final s = await _repository.loadSettings();
    if (s == _settings) return;
    _settings = s;
    notifyListeners();
  }
}
