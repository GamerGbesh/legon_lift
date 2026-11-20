import 'dart:convert';
import 'dart:io';

import 'package:legon_lift/data/assets/json_asset_catalog.dart';

JsonAssetCatalog? _cached;

/// The real bundled data, read from `assets/data/` (run tests from the project root).
/// Parsed once per test isolate.
JsonAssetCatalog loadTestCatalog() => _cached ??= JsonAssetCatalog.fromDecoded(
      exercisesJson: _read(JsonAssetCatalog.exercisesAsset),
      programsJson: _read(JsonAssetCatalog.programsAsset),
      personalizationJson: _read(JsonAssetCatalog.personalizationAsset),
    );

Object? _read(String asset) => jsonDecode(File(asset).readAsStringSync());
