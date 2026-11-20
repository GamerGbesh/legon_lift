// Owner: WS5. Small building blocks shared by the Progress views, session detail and Library.
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';
import '../../widgets/big_button.dart';

/// A chart inside a card with chart-friendly padding.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.fromLTRB(Space.s, Space.l, Space.l, Space.s), child: child),
      );
}

/// A full-width, at least 56 dp tall tappable row (gym-floor tap target).
class TapRow extends StatelessWidget {
  const TapRow({super.key, required this.leading, required this.title, required this.subtitle, required this.onTap});

  final Widget leading;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.minTap + 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s),
          child: Row(
            children: [
              leading,
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body.copyWith(color: t.onSurface, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: AppText.tabular(AppText.label).copyWith(color: t.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Type a number with the keypad (tap on a stepper value). Pops the value, or null.
class NumberEntrySheet extends StatefulWidget {
  const NumberEntrySheet({super.key, required this.title, required this.initial, this.max = 1000});

  final String title;
  final double initial;

  /// Largest accepted value.
  final double max;

  @override
  State<NumberEntrySheet> createState() => _NumberEntrySheetState();
}

class _NumberEntrySheetState extends State<NumberEntrySheet> {
  late final TextEditingController _c = TextEditingController(text: Fmt.number(widget.initial));

  double? get _value {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    return v == null || v < 0 || v > widget.max ? null : v;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            Space.page, 0, Space.page, Space.page + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppText.title.copyWith(color: context.tokens.onSurface)),
            const SizedBox(height: Space.m),
            TextField(
              controller: _c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppText.value,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_value != null) Navigator.of(context).pop(_value);
              },
            ),
            const SizedBox(height: Space.l),
            BigButton(label: 'Use this', onPressed: _value == null ? null : () => Navigator.of(context).pop(_value)),
          ],
        ),
      );
}
