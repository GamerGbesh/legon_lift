import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// A new random id (UUID v4) for sessions, set logs, programs and other rows.
String newId() => _uuid.v4();
