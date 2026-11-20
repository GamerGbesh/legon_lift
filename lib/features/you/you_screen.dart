// Owner: WS4. Phase 0 stub (SPEC 4.12): links only; the owner adds the profile summary and editing.
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';

/// "You" tab: profile and links to Body, Food, Milestones, Safety, Settings, Backup.
class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const links = [
      (Icons.monitor_weight, 'Body', Routes.body),
      (Icons.restaurant, 'Food', Routes.nutrition),
      (Icons.emoji_events, 'Milestones', Routes.milestones),
      (Icons.health_and_safety, 'Safety', Routes.safety),
      (Icons.settings, 'Settings', Routes.settings),
      (Icons.backup, 'Backup', Routes.backup),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        children: [
          for (final (icon, label, route) in links)
            ListTile(
              minTileHeight: Sizes.minTap,
              leading: Icon(icon),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(route),
            ),
        ],
      ),
    );
  }
}
