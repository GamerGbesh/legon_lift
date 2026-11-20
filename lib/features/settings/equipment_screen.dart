// Owner: WS1. Settings > Equipment (SPEC 4.12): the shared EquipmentEditor on its own page.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/settings_store.dart';
import '../../widgets/big_button.dart';
import 'widgets/equipment_editor.dart';

/// Every change is saved at once (no Save button to forget).
class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const EquipmentScreen());

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final settings = store.settings;
    final defaults = context.read<AssetCatalog>().personalization.gym;
    void save(EquipmentProfile eq) => unawaited(store.update(settings.copyWith(equipment: eq)));
    return Scaffold(
      appBar: AppBar(title: const Text('Gym equipment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
        children: [
          EquipmentEditor(value: settings.equipment, defaults: defaults, onChanged: save),
          const SizedBox(height: Space.xxl),
          BigButton(
            label: 'Back to UG gym defaults',
            icon: Icons.settings_backup_restore,
            kind: BigButtonKind.secondary,
            height: Sizes.minTap,
            onPressed: settings.equipment == EquipmentProfile.fromDefaults(defaults)
                ? null
                : () {
                    final before = settings.equipment;
                    save(EquipmentProfile.fromDefaults(defaults));
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(SnackBar(
                      content: const Text('Equipment set back to the UG gym defaults.'),
                      duration: Motion.snackUndo,
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => unawaited(store.update(store.settings.copyWith(equipment: before))),
                      ),
                    ));
                  },
          ),
        ],
      ),
    );
  }
}
