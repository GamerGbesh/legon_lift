/// App identity shown in About and written into backups. Keep in step with `version:` in
/// pubspec.yaml (1.0.0+1).
abstract final class AppInfo {
  static const String name = 'Legon Lift';
  static const String version = '1.0.0';
  static const int buildNumber = 1;

  /// `1.0.0+1`, as in pubspec.yaml.
  static const String fullVersion = '$version+$buildNumber';
}
