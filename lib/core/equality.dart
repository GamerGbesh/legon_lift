import 'package:collection/collection.dart';

/// Deep equality helpers used by the immutable models (`==` / `hashCode` over a property list).
const DeepCollectionEquality _deep = DeepCollectionEquality();

/// True when the two property lists are deeply equal (lists, sets, maps, records).
bool propsEqual(List<Object?> a, List<Object?> b) => _deep.equals(a, b);

/// Deep hash of a property list, consistent with [propsEqual].
int propsHash(List<Object?> props) => _deep.hash(props);
