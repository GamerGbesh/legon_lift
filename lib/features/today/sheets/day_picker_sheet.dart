// Owner: WS4. "Do a different day" (SPEC 4.3): any day of the rotation.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../state/program_store.dart';
import '../../../widgets/option_card.dart';

/// Returns the chosen day id (null when dismissed).
Future<String?> showDayPicker(BuildContext context, {required String currentDayId}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final t = context.tokens;
        final days = context.read<ProgramStore>().days;
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page),
            children: [
              Text('Do a different day', style: AppText.headline.copyWith(color: t.onSurface)),
              Text('Your rotation moves on from the day you do.', style: AppText.body.copyWith(color: t.muted)),
              const SizedBox(height: Space.m),
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: OptionCard(
                    title: Copy.dayShort(d.name),
                    subtitle: d.focus.map(Copy.focus).join(', '),
                    badge: d.dayId == currentDayId ? 'Next up' : null,
                    selected: d.dayId == currentDayId,
                    onTap: () => Navigator.of(context).pop(d.dayId),
                  ),
                ),
            ],
          ),
        );
      },
    );
