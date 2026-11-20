import 'package:intl/intl.dart';

import 'units.dart';

/// Formatting helpers shared by every screen. Plain language, tabular-friendly numbers.
abstract final class Fmt {
  static final DateFormat _dateKey = DateFormat('yyyy-MM-dd');

  /// Calendar date key used in storage (`yyyy-MM-dd`, local), SPEC 0.3.
  static String dateKey(DateTime local) => _dateKey.format(local);

  /// Parses a `yyyy-MM-dd` key back to a local midnight.
  static DateTime parseDateKey(String key) => _dateKey.parseStrict(key);

  /// A number without trailing zeros: 20 -> "20", 22.5 -> "22.5", 1.25 -> "1.25".
  static String number(double value, {int maxDecimals = 2}) {
    final fixed = value.toStringAsFixed(maxDecimals);
    if (!fixed.contains('.')) return fixed;
    final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  /// A stored kg value in the user's unit with its suffix: "22.5 kg" or "49.6 lb".
  static String weight(double kg, {bool useLb = false, int maxDecimals = 2}) {
    final shown = Units.displayWeight(kg, useLb: useLb);
    return '${number(shown, maxDecimals: useLb ? 1 : maxDecimals)} ${Units.weightUnit(useLb: useLb)}';
  }

  /// Signed weight change: "+2.5 kg", "-5 kg".
  static String weightDelta(double kg, {bool useLb = false}) {
    final sign = kg > 0 ? '+' : (kg < 0 ? '-' : '');
    return '$sign${weight(kg.abs(), useLb: useLb)}';
  }

  /// Countdown style: 125 -> "2:05", 3725 -> "1:02:05".
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
  }

  /// Rounded minutes for estimates: 3120 -> "52 min".
  static String minutes(int seconds) => '${(seconds / 60).round()} min';

  /// Height in the user's unit: "172 cm" or "5 ft 8 in".
  static String height(double cm, {bool useFtIn = false}) {
    if (!useFtIn) return '${number(cm, maxDecimals: 1)} cm';
    final (ft, inches) = Units.cmToFtIn(cm);
    return '$ft ft $inches in';
  }

  /// Weekday short name, 1 = Monday ... 7 = Sunday.
  static String weekdayShort(int weekday) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  /// Plain-language reps-in-reserve answer (SPEC 12.1): 4 -> "4+ left (easy)", 0 -> "none left".
  static String rirAnswer(int rir) => switch (rir) {
        <= 0 => 'none left',
        1 => '1 left',
        2 => '2 left',
        3 => '3 left',
        _ => '4+ left (easy)',
      };

  /// Plain-language target RIR (SPEC 12.1): "leave 2 in the tank".
  static String rirTarget(int rir) => 'leave $rir in the tank';
}
