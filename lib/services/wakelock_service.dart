// Owner: WS3.
import 'package:wakelock_plus/wakelock_plus.dart';

import 'api.dart';

/// [WakelockService] on wakelock_plus.
class PlusWakelockService implements WakelockService {
  const PlusWakelockService();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}
