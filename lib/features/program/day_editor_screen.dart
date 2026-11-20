// Owner: WS4. Phase 0 stub (SPEC 4.5); the owner replaces the body. Constructor frozen (route args, SPEC 3.2).
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../widgets/empty_state.dart';

/// Edit day screen.
class DayEditorScreen extends StatelessWidget {
  const DayEditorScreen({super.key, required this.dayId});

  /// The program day to edit.
  final String dayId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit day')),
        body: const Padding(
          padding: EdgeInsets.all(Space.page),
          child: EmptyState(icon: Icons.construction, title: 'Edit day', body: 'This screen is being built.'),
        ),
      );
}
