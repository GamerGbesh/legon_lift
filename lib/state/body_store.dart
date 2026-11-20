// Owner: WS5. Body weight and waist entries (SPEC 4.8).
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../data/models/models.dart';
import '../data/repositories/body_repository.dart';
import '../domain/api.dart';

/// Body weight and waist entries (SPEC 4.8). One entry per date; saving a date again replaces it.
class BodyStore extends ChangeNotifier {
  BodyStore({required this._body, required this._clock});

  final BodyRepository _body;
  final Clock _clock;
  List<BodyEntry> _entries = const [];
  bool _disposed = false;

  /// All entries, ascending by date.
  List<BodyEntry> get entries => _entries;

  /// 7-day average weight ending today; null with fewer than 3 weigh-ins.
  double? get avg7 => movingAverage7(_entries, Fmt.dateKey(_clock.now()));

  /// Today's date key (`yyyy-MM-dd`, local).
  String get todayKey => Fmt.dateKey(_clock.now());

  /// Weigh-ins in the 7 days ending today (the average needs 3).
  int get weighInsLast7 => weighInsInWindow(_entries, todayKey);

  /// The entry saved for [date], if any.
  BodyEntry? entryFor(String date) {
    for (final e in _entries) {
      if (e.date == date) return e;
    }
    return null;
  }

  /// Latest entry with a weight / with a waist measurement.
  BodyEntry? get latestWeight => _entries.lastWhereOrNull((e) => e.weightKg != null);
  BodyEntry? get latestWaist => _entries.lastWhereOrNull((e) => e.waistCm != null);

  Future<void> load() async {
    final all = await _body.range('0000-01-01', '9999-12-31');
    if (_disposed) return;
    _entries = List.unmodifiable(all);
    notifyListeners();
  }

  /// One entry per date: saving a date again replaces it. An entry with neither weight nor
  /// waist deletes the date instead.
  Future<void> upsert(BodyEntry e) async {
    if (e.weightKg == null && e.waistCm == null && (e.note == null || e.note!.isEmpty)) {
      await _body.delete(e.date);
    } else {
      await _body.upsert(e);
    }
    await load();
  }

  /// Deletes the entry of [date] (the screen offers Undo by saving it again).
  Future<void> delete(String date) async {
    await _body.delete(date);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Number of weigh-ins in [date-6, date] (SPEC 4.8: the 7-day average needs 3).
int weighInsInWindow(List<BodyEntry> entries, String date) {
  final end = Fmt.parseDateKey(date);
  final start = Fmt.dateKey(DateTime(end.year, end.month, end.day - 6));
  return entries.where((e) => e.weightKg != null && e.date.compareTo(start) >= 0 && e.date.compareTo(date) <= 0).length;
}
