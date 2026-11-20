import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/features/body/recomp_insight.dart';
import 'package:legon_lift/state/body_store.dart';

import '../../fakes/fakes.dart';

void main() {
  group('BodyStore', () {
    late FakeApp app;
    late BodyStore store;

    setUp(() async {
      app = FakeApp.seeded();
      store = BodyStore(body: app.body, clock: app.clock);
      await store.load();
    });

    tearDown(() => store.dispose());

    test('7-day average ends today and needs 3 weigh-ins', () {
      // Today is Mon 16 Nov: the window is 10-16 Nov, six sample weigh-ins.
      expect(store.weighInsLast7, 6);
      expect(store.avg7, closeTo((94.8 + 95.1 + 94.6 + 94.7 + 94.3 + 94.4) / 6, 1e-9));
      app.clock.set(DateTime(2026, 11, 20, 8));
      expect(store.weighInsLast7, 2);
      expect(store.avg7, isNull);
    });

    test('one entry per date: saving again replaces it', () async {
      await store.upsert(const BodyEntry(date: '2026-11-16', weightKg: 94.2));
      await store.upsert(const BodyEntry(date: '2026-11-16', weightKg: 94.1, waistCm: 103));
      expect(store.entries.where((e) => e.date == '2026-11-16'), hasLength(1));
      expect(store.entryFor('2026-11-16'), const BodyEntry(date: '2026-11-16', weightKg: 94.1, waistCm: 103));
      expect(store.latestWaist?.date, '2026-11-16');
      expect(store.entries.map((e) => e.date).toList(), [...store.entries.map((e) => e.date)]..sort());
    });

    test('an empty entry deletes the date; delete removes it', () async {
      await store.upsert(const BodyEntry(date: '2026-11-15'));
      expect(store.entryFor('2026-11-15'), isNull);
      await store.delete('2026-11-14');
      expect(app.body.entries.containsKey('2026-11-14'), isFalse);
      expect(store.entryFor('2026-11-14'), isNull);
    });

    test('weighInsInWindow counts weigh-ins only', () {
      const entries = [
        BodyEntry(date: '2026-11-01', weightKg: 90),
        BodyEntry(date: '2026-11-05', waistCm: 100),
        BodyEntry(date: '2026-11-07', weightKg: 90),
        BodyEntry(date: '2026-11-08', weightKg: 90),
      ];
      expect(weighInsInWindow(entries, '2026-11-07'), 2);
      expect(weighInsInWindow(entries, '2026-11-08'), 2);
    });
  });

  group('recompInsight', () {
    List<BodyEntry> series({required double from, required double to, double? waistFrom, double? waistTo}) => [
          for (var d = 0; d < 21; d++)
            BodyEntry(
              date: '2026-10-${(d + 1).toString().padLeft(2, '0')}',
              weightKg: from + (to - from) * d / 20,
              waistCm: d == 0 ? waistFrom : (d == 20 ? waistTo : null),
            ),
        ];

    test('asks to keep logging with too little data', () {
      expect(recompInsight(const []).title, 'Keep logging');
      expect(recompInsight(series(from: 95, to: 94).take(10).toList()).title, 'Keep logging');
    });

    test('waist down, weight steady = recomp', () {
      final i = recompInsight(series(from: 95, to: 94.9, waistFrom: 104, waistTo: 102));
      expect(i.title, 'Recomp is working');
      expect(i.message, contains('2 cm'));
      expect(i.tone, InsightTone.good);
    });

    test('weight and waist down = losing fat', () {
      final i = recompInsight(series(from: 95, to: 93, waistFrom: 104, waistTo: 101));
      expect(i.title, 'Losing fat');
    });

    test('weight down without waist asks for a waist measurement', () {
      final i = recompInsight(series(from: 95, to: 93.5));
      expect(i.title, 'Weight trending down');
      expect(i.message, contains('waist'));
    });

    test('both up = watch', () {
      final i = recompInsight(series(from: 95, to: 96.5, waistFrom: 104, waistTo: 106));
      expect(i.tone, InsightTone.watch);
    });

    test('steady and units', () {
      expect(recompInsight(series(from: 95, to: 95.1)).title, 'Holding steady');
      final lb = recompInsight(series(from: 95, to: 93), useLb: true);
      expect(lb.message, contains('lb'));
      final inches = recompInsight(series(from: 95, to: 95, waistFrom: 104, waistTo: 99), useInches: true);
      expect(inches.message, contains('in'));
    });
  });
}
