/// SQLite schema (SPEC 9.1). Database `legon_lift.db`, version [kDbVersion].
/// Owned by WS1: every change bumps the version and adds a migration in `migrations.dart`.
library;

const String kDbName = 'legon_lift.db';
const int kDbVersion = 1;

/// Table names, in foreign-key order (parents first). Backup replace deletes in reverse order.
const List<String> kTables = [
  'kv',
  'programs',
  'program_overrides',
  'sessions',
  'session_exercises',
  'set_logs',
  'exercise_state',
  'personal_records',
  'exercise_prefs',
  'body_entries',
  'nutrition_days',
  'calorie_adjustments',
  'cardio_logs',
  'pauses',
  'milestone_awards',
];

/// kv keys.
abstract final class KvKeys {
  static const String profile = 'profile';
  static const String settings = 'settings';

  /// Prefix of free-form flags (`flags.<name>`), e.g. one-time explainers.
  static const String flagPrefix = 'flags.';
}

/// Statements that create schema version 1, in order.
const List<String> kSchemaV1 = [
  '''CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
  '''CREATE TABLE programs (
  id TEXT PRIMARY KEY, template_id TEXT, name TEXT NOT NULL, custom_json TEXT,
  day_order_json TEXT NOT NULL, next_day_index INTEGER NOT NULL DEFAULT 0,
  started_at INTEGER NOT NULL, start_week INTEGER NOT NULL DEFAULT 1, cycle INTEGER NOT NULL DEFAULT 1,
  reactive_deload_remaining INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL)''',
  '''CREATE TABLE program_overrides (
  program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE, day_id TEXT NOT NULL,
  slot_key TEXT NOT NULL, exercise_id TEXT, optional_enabled INTEGER,
  PRIMARY KEY (program_id, day_id, slot_key))''',
  '''CREATE TABLE sessions (
  id TEXT PRIMARY KEY, program_id TEXT NOT NULL, template_id TEXT, phase_id TEXT NOT NULL,
  training_week INTEGER NOT NULL, day_id TEXT NOT NULL, day_name TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at INTEGER NOT NULL, ended_at INTEGER, is_deload INTEGER NOT NULL DEFAULT 0,
  hot_day INTEGER NOT NULL DEFAULT 0, readiness_sleep INTEGER, readiness_soreness INTEGER, readiness_energy INTEGER,
  bodyweight_kg REAL, feeling INTEGER, note TEXT, cursor_json TEXT, plan_json TEXT NOT NULL,
  total_volume_kg REAL NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)''',
  '''CREATE INDEX idx_sessions_started ON sessions(started_at)''',
  '''CREATE INDEX idx_sessions_status ON sessions(status)''',
  '''CREATE TABLE session_exercises (
  id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  position INTEGER NOT NULL, block_index INTEGER NOT NULL, block_type TEXT NOT NULL, superset_group TEXT,
  exercise_id TEXT NOT NULL, original_exercise_id TEXT, slot_key TEXT NOT NULL, role TEXT NOT NULL,
  status TEXT NOT NULL, skip_reason TEXT, target_json TEXT NOT NULL, note TEXT)''',
  '''CREATE INDEX idx_se_session ON session_exercises(session_id, position)''',
  '''CREATE TABLE set_logs (
  id TEXT PRIMARY KEY,
  session_exercise_id TEXT NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL,
  kind TEXT NOT NULL,
  target_kg REAL, target_reps INTEGER, weight_kg REAL NOT NULL, reps INTEGER NOT NULL, duration_sec INTEGER,
  rir INTEGER, calibration_extra_reps INTEGER, pain_flag INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER NOT NULL, is_pr INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE INDEX idx_sets_exercise_time ON set_logs(exercise_id, completed_at)''',
  '''CREATE INDEX idx_sets_session ON set_logs(session_id)''',
  '''CREATE TABLE exercise_state (
  exercise_id TEXT PRIMARY KEY, working_kg REAL, rep_targets_json TEXT NOT NULL DEFAULT '[]',
  stall_count INTEGER NOT NULL DEFAULT 0, reset_count INTEGER NOT NULL DEFAULT 0,
  last_trend TEXT NOT NULL DEFAULT 'calibrate', last_reason TEXT NOT NULL DEFAULT '',
  last_session_id TEXT, last_rep_min INTEGER, last_rep_max INTEGER, first_e1rm REAL, best_e1rm REAL,
  last_jump_pct REAL, updated_at INTEGER NOT NULL)''',
  '''CREATE TABLE personal_records (
  exercise_id TEXT NOT NULL, type TEXT NOT NULL, value REAL NOT NULL, set_log_id TEXT NOT NULL,
  achieved_at INTEGER NOT NULL, PRIMARY KEY (exercise_id, type))''',
  '''CREATE TABLE exercise_prefs (
  exercise_id TEXT PRIMARY KEY, favorite INTEGER NOT NULL DEFAULT 0, hidden INTEGER NOT NULL DEFAULT 0,
  increment_kg REAL, machine_note TEXT, last_pain_at INTEGER)''',
  '''CREATE TABLE body_entries (date TEXT PRIMARY KEY, weight_kg REAL, waist_cm REAL, note TEXT, updated_at INTEGER NOT NULL)''',
  '''CREATE TABLE nutrition_days (
  date TEXT PRIMARY KEY, protein_points REAL NOT NULL DEFAULT 0, water_sachets REAL NOT NULL DEFAULT 0,
  veg_fruit INTEGER NOT NULL DEFAULT 0, steps_hit INTEGER NOT NULL DEFAULT 0, steps INTEGER,
  sleep_ok INTEGER NOT NULL DEFAULT 0, no_sugary_drinks INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)''',
  '''CREATE TABLE calorie_adjustments (id TEXT PRIMARY KEY, date TEXT NOT NULL, rule_id TEXT NOT NULL,
  delta_kcal INTEGER NOT NULL DEFAULT 0, delta_steps INTEGER)''',
  '''CREATE TABLE cardio_logs (id TEXT PRIMARY KEY, date TEXT NOT NULL, exercise_id TEXT NOT NULL,
  duration_sec INTEGER NOT NULL, note TEXT)''',
  '''CREATE TABLE pauses (id TEXT PRIMARY KEY, kind TEXT NOT NULL, reason TEXT NOT NULL, start_date TEXT NOT NULL,
  end_date TEXT)''',
  '''CREATE TABLE milestone_awards (milestone_id TEXT PRIMARY KEY, awarded_at INTEGER NOT NULL, context_json TEXT)''',
];
