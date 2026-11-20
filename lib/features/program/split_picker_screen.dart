// Owner: WS4. Phase 0 stub (SPEC 4.5); the owner replaces the body.
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../widgets/empty_state.dart';

/// Change split screen.
class SplitPickerScreen extends StatelessWidget {
  const SplitPickerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change split')),
        body: const Padding(
          padding: EdgeInsets.all(Space.page),
          child: EmptyState(icon: Icons.construction, title: 'Change split', body: 'This screen is being built.'),
        ),
      );
}
