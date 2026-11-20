// Owner: WS3. Phase 0 stub (SPEC 4.4); the owner replaces the body. Constructor frozen (route args, SPEC 3.2).
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../widgets/empty_state.dart';

/// Workout summary screen.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.sessionId});

  /// The completed session.
  final String sessionId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Workout summary')),
        body: const Padding(
          padding: EdgeInsets.all(Space.page),
          child: EmptyState(icon: Icons.construction, title: 'Workout summary', body: 'This screen is being built.'),
        ),
      );
}
