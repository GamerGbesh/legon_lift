// Deleting a workout logged by mistake. Only allowed on the day it was logged and only for the
// most recent workout (SessionRepository.canDelete); the repository restores what finishing it
// changed (weights for next time, personal bests, program rotation, milestones).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/session_repository.dart';
import '../../state/milestone_store.dart';
import '../../state/program_store.dart';
import '../../state/today_store.dart';

/// Asks for confirmation, deletes [session] and reloads the stores that cached its effects.
/// Returns true when the workout was deleted.
Future<bool> confirmAndDeleteWorkout(BuildContext context, Session session) async {
  final sessions = context.read<SessionRepository>();
  final programs = context.read<ProgramStore>();
  final milestones = context.read<MilestoneStore>();
  final today = context.read<TodayStore>();
  final messenger = ScaffoldMessenger.of(context);
  if (!await sessions.canDelete(session.id)) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Only your latest workout can be deleted, and only on the day you logged it.'),
    ));
    return false;
  }
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: Text('Delete ${session.dayName}?'),
      content: const Text(
        "Use this if you logged a workout by mistake. Its sets are removed, your weights for next time "
        'go back to what they were, and this day comes up again as your next workout. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete workout')),
      ],
    ),
  );
  if (ok != true) return false;
  await sessions.deleteCompleted(session.id);
  await programs.load();
  await milestones.load();
  await today.refresh();
  messenger.showSnackBar(const SnackBar(content: Text('Workout deleted')));
  return true;
}
