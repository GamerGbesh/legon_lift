// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';

/// A labelled number card (summary tiles, progress overview).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.delta});

  final String label;
  final String value;

  /// Optional change line ("+2.5 kg"). A leading "+" shows in green, anything else muted.
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = delta;
    return Semantics(
      label: '$label: $value${d == null ? '' : ', $d'}',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.label.copyWith(color: t.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: Space.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppText.displayStat.copyWith(fontSize: 40, color: t.onSurface)),
              ),
              if (d != null)
                Text(
                  d,
                  style: AppText.label.copyWith(color: d.startsWith('+') ? t.success : t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
