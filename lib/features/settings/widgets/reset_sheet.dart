// Owner: WS1. "Reset all data" confirmation (SPEC 4.12: typed confirmation "RESET").
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../widgets/big_button.dart';

/// Pops `true` once the user typed RESET and tapped the button; dismissing pops null.
class ResetSheet extends StatefulWidget {
  const ResetSheet({super.key});

  static const String word = 'RESET';

  @override
  State<ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<ResetSheet> {
  final TextEditingController _text = TextEditingController();

  bool get _confirmed => _text.text.trim().toUpperCase() == ResetSheet.word;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Erase everything?', style: AppText.headline.copyWith(color: t.onSurface)),
            const SizedBox(height: Space.m),
            Text(
              'This deletes your workouts, weights, body and food logs, milestones, settings and profile. '
              'You will start again from the setup.',
              style: AppText.body.copyWith(color: t.onSurface),
            ),
            const SizedBox(height: Space.s),
            Text(
              'A safety copy is saved first in Backup > Automatic backups.',
              style: AppText.label.copyWith(color: t.muted),
            ),
            const SizedBox(height: Space.l),
            TextField(
              controller: _text,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              style: AppText.body.copyWith(color: t.onSurface, fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Type ${ResetSheet.word} to confirm',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_confirmed) Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: Space.xl),
            BigButton(
              label: 'Erase everything',
              icon: Icons.delete_forever,
              kind: BigButtonKind.destructive,
              height: Sizes.minTap,
              onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: Space.s),
            BigButton(
              label: 'Keep my data',
              kind: BigButtonKind.secondary,
              height: Sizes.minTap,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
