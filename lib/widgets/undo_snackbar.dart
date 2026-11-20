// Owner: WS4. Shared helper; signature frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';

/// 5-second snackbar with "Undo" (used instead of confirmation dialogs, SPEC 4.1).
void showUndoSnackBar(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: Motion.snackUndo,
    action: SnackBarAction(label: 'Undo', onPressed: onUndo),
  ));
}
