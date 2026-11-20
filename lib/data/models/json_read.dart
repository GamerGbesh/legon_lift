// Small typed readers for decoded JSON / SQLite rows. They throw FormatException with the field
// name so schema errors in assets or backups produce a clear message.

typedef Json = Map<String, dynamic>;

Never _bad(String key, String expected, Object? got) =>
    throw FormatException('Field "$key": expected $expected, got ${got == null ? 'null' : got.runtimeType} ($got)');

Object? _get(Map<String, dynamic> m, String key) => m[key];

String readString(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  return v is String ? v : _bad(key, 'string', v);
}

String? readStringOrNull(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  return v == null || v is String ? v as String? : _bad(key, 'string or null', v);
}

int readInt(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  if (v is int) return v;
  if (v is double && v == v.roundToDouble()) return v.toInt();
  return _bad(key, 'int', v);
}

int? readIntOrNull(Map<String, dynamic> m, String key) => _get(m, key) == null ? null : readInt(m, key);

double readDouble(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  return v is num ? v.toDouble() : _bad(key, 'number', v);
}

double? readDoubleOrNull(Map<String, dynamic> m, String key) => _get(m, key) == null ? null : readDouble(m, key);

/// Booleans arrive as `true/false` in JSON and as `0/1` in SQLite rows.
bool readBool(Map<String, dynamic> m, String key, {bool? fallback}) {
  final v = _get(m, key);
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v == null && fallback != null) return fallback;
  return _bad(key, 'bool', v);
}

bool? readBoolOrNull(Map<String, dynamic> m, String key) => _get(m, key) == null ? null : readBool(m, key);

Map<String, dynamic> readMap(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  return v is Map ? v.cast<String, dynamic>() : _bad(key, 'object', v);
}

Map<String, dynamic>? readMapOrNull(Map<String, dynamic> m, String key) => _get(m, key) == null ? null : readMap(m, key);

List<dynamic> readList(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  return v is List ? v : _bad(key, 'array', v);
}

List<String> readStringList(Map<String, dynamic> m, String key, {bool optional = false}) {
  if (optional && _get(m, key) == null) return const [];
  return [for (final (i, e) in readList(m, key).indexed) e is String ? e : _bad('$key[$i]', 'string', e)];
}

List<int> readIntList(Map<String, dynamic> m, String key, {bool optional = false}) {
  if (optional && _get(m, key) == null) return const [];
  return [for (final (i, e) in readList(m, key).indexed) e is num ? e.toInt() : _bad('$key[$i]', 'int', e)];
}

List<double> readDoubleList(Map<String, dynamic> m, String key, {bool optional = false}) {
  if (optional && _get(m, key) == null) return const [];
  return [for (final (i, e) in readList(m, key).indexed) e is num ? e.toDouble() : _bad('$key[$i]', 'number', e)];
}

/// Objects of a list, each converted by [f]; errors name the index.
List<T> readObjectList<T>(Map<String, dynamic> m, String key, T Function(Map<String, dynamic>) f) {
  final out = <T>[];
  for (final (i, e) in readList(m, key).indexed) {
    if (e is! Map) _bad('$key[$i]', 'object', e);
    try {
      out.add(f(e.cast<String, dynamic>()));
    } on FormatException catch (err) {
      throw FormatException('$key[$i]: ${err.message}');
    }
  }
  return out;
}

/// `[min, max]` rep range or null.
(int, int)? readRangeOrNull(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  if (v == null) return null;
  if (v is List && v.length == 2 && v[0] is num && v[1] is num) {
    return ((v[0] as num).toInt(), (v[1] as num).toInt());
  }
  return _bad(key, '[min, max]', v);
}

(double, double)? readDoubleRangeOrNull(Map<String, dynamic> m, String key) {
  final v = _get(m, key);
  if (v == null) return null;
  if (v is List && v.length == 2 && v[0] is num && v[1] is num) {
    return ((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }
  return _bad(key, '[min, max]', v);
}

List<int>? rangeToJson((int, int)? r) => r == null ? null : [r.$1, r.$2];

/// Epoch milliseconds (UTC instant) to a local DateTime.
DateTime readInstant(Map<String, dynamic> m, String key) =>
    DateTime.fromMillisecondsSinceEpoch(readInt(m, key), isUtc: true).toLocal();

DateTime? readInstantOrNull(Map<String, dynamic> m, String key) => _get(m, key) == null ? null : readInstant(m, key);

int instantToJson(DateTime d) => d.millisecondsSinceEpoch;

int? instantToJsonOrNull(DateTime? d) => d?.millisecondsSinceEpoch;

/// Enum list reader using a `fromWire` function.
List<E> readEnumList<E>(Map<String, dynamic> m, String key, E Function(String) fromWire) =>
    [for (final s in readStringList(m, key)) fromWire(s)];

int boolToInt(bool b) => b ? 1 : 0;
