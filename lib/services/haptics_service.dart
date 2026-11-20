// Owner: WS3.
import 'package:flutter/services.dart';

import 'api.dart';

/// [HapticsService] on the platform haptic feedback API.
class DeviceHapticsService implements HapticsService {
  const DeviceHapticsService();

  @override
  Future<void> light() => HapticFeedback.lightImpact();

  @override
  Future<void> heavyTriple() async {
    for (var i = 0; i < 3; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    }
  }
}
