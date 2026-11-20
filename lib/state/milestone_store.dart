// Owner: WS6. Milestones (SPEC 4.10, 10.3).
import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import '../domain/api.dart';
import 'profile_store.dart';
import 'settings_store.dart';

/// Earned badges and their progress.
///
/// [evaluateNow] should run after each session completion, body entry and nutrition day save,
/// and once a day on app open (SPEC 4.10). Calls are queued, so concurrent callers each get the
/// result of their own evaluation.
///
/// Public API of SPEC 7.4 ([awards], [recent], [evaluateNow]) plus WS6 additions for the
/// Milestones screen: [load], [milestones], [awardFor], [progress], [refreshProgress],
/// [isRepeatable], [isLowEmphasis].
class MilestoneStore extends ChangeNotifier {
  MilestoneStore({
    required this._milestones,
    required this._catalog,
    required this._sessions,
    required this._body,
    required this._nutrition,
    required this._activity,
    required this._states,
    required this._settings,
    required this._profile,
    required this._clock,
  });

  final MilestoneRepository _milestones;
  final AssetCatalog _catalog;
  final SessionRepository _sessions;
  final BodyRepository _body;
  final NutritionRepository _nutrition;
  final ActivityRepository _activity;
  final ExerciseStateRepository _states;
  final ProfileStore _profile;
  final SettingsStore _settings;
  final Clock _clock;

  List<MilestoneAward> _awards = const [];
  List<Milestone> _recent = const [];
  Map<String, MilestoneProgress> _progress = const {};

  /// Sessions that ended after this instant are "new" for the repeatable PR milestone. Null until
  /// the first evaluation after [load].
  DateTime? _watermark;
  bool _watermarkSet = false;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  List<MilestoneAward> get awards => _awards;

  /// Milestones earned by the last [evaluateNow] (for the summary and the Today card).
  List<Milestone> get recent => _recent;

  /// Every milestone of the data file, in data order.
  List<Milestone> get milestones => _catalog.personalization.milestones;

  /// The (first) award of [milestoneId], if earned.
  MilestoneAward? awardFor(String milestoneId) => _awards.where((a) => a.milestoneId == milestoneId).firstOrNull;

  /// Progress of measurable milestones, filled by [evaluateNow] / [refreshProgress].
  Map<String, MilestoneProgress> get progress => _progress;

  bool isRepeatable(String milestoneId) => repeatableMilestoneIds(_catalog.personalization).contains(milestoneId);

  bool isLowEmphasis(String milestoneId) => lowEmphasisMilestoneIds(_catalog.personalization).contains(milestoneId);

  /// Reads the awards. Evaluation itself is triggered by the callers (Today on app open, the
  /// player after a session, the Food and Body screens after saving).
  Future<void> load() async {
    _awards = await _milestones.awards();
    _recent = const [];
    _watermark = null;
    _watermarkSet = false;
    _notify();
  }

  /// Evaluates every rule, stores new awards and returns the newly earned milestones.
  Future<List<Milestone>> evaluateNow() {
    final result = _queue.then((_) => _evaluate());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Recomputes [progress] without awarding anything (opening the Milestones screen).
  Future<void> refreshProgress() {
    final result = _queue.then((_) async {
      final input = await _input(const []);
      if (input == null) return;
      _progress = milestoneProgress(input, _catalog.personalization);
      _notify();
    });
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<List<Milestone>> _evaluate() async {
    final p = _catalog.personalization;
    final now = _clock.now();
    _awards = await _milestones.awards();
    final awarded = {for (final a in _awards) a.milestoneId};

    // First evaluation: if "New PR" was never earned, the whole history may earn it; otherwise
    // only sessions finished from now on count as new.
    if (!_watermarkSet) {
      final prEarned = awarded.any(repeatableMilestoneIds(p).contains);
      _watermark = prEarned ? now : null;
      _watermarkSet = true;
    }
    final completed = await _sessions.listCompleted();
    final since = _watermark;
    final fresh = [
      for (final s in completed)
        if (since == null || (s.endedAt ?? s.startedAt).isAfter(since)) s,
    ];
    final input = await _input(await _newPrs(fresh), completed: completed);
    if (input == null) return const [];

    final earned = evaluateMilestones(input, p, awarded);
    for (final a in earned) {
      await _milestones.award(a);
    }
    _watermark = now;
    _awards = await _milestones.awards();
    _progress = milestoneProgress(input, p);
    final ids = {for (final a in earned) a.milestoneId};
    _recent = [for (final m in p.milestones) if (ids.contains(m.id)) m];
    _notify();
    return _recent;
  }

  /// Estimated-best-single records set in [sessions].
  Future<List<PersonalRecord>> _newPrs(List<Session> sessions) async {
    final setIds = {for (final s in sessions) for (final x in s.allSets) x.id};
    final exerciseIds = {for (final s in sessions) for (final x in s.allSets) x.exerciseId};
    final out = <PersonalRecord>[];
    for (final id in exerciseIds) {
      for (final r in await _states.records(id)) {
        if (r.type == PrType.e1rm && setIds.contains(r.setLogId)) out.add(r);
      }
    }
    return out;
  }

  Future<MilestoneInput?> _input(List<PersonalRecord> newPrs, {List<Session>? completed}) async {
    final profile = _profile.profile;
    if (profile == null) return null;
    final now = _clock.now();
    final sessions = completed ?? await _sessions.listCompleted();
    final sets = [
      for (final s in sessions)
        for (final x in s.allSets)
          if (x.kind == SetKind.working || x.kind == SetKind.test) x,
    ];
    final today = Fmt.dateKey(now);
    const from = '0000-01-01';
    return MilestoneInput(
      sessions: sessions,
      workingSets: sets,
      body: await _body.range(from, today),
      nutrition: await _nutrition.range(from, today),
      cardio: await _activity.cardio(from, today),
      pauses: await _activity.pauses(),
      states: await _states.getAll({for (final x in sets) x.exerciseId}),
      newPrs: newPrs,
      profile: profile,
      eq: _settings.settings.equipment,
      catalog: _catalog,
      now: now,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
