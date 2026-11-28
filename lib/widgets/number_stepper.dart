// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';
import '../core/format.dart';
import 'number_entry_sheet.dart';

/// (-) value unit (+) with 64 dp buttons and a 40 sp value. Tapping the value calls [onTapValue],
/// or, when that is null, opens the number keypad (`showNumberEntrySheet`, titled [entryTitle]).
/// The buttons disable at [min] / [max].
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.step,
    required this.onChanged,
    required this.unit,
    this.min = 0,
    this.max,
    this.decimals = 1,
    this.onTapValue,
    this.entryTitle,
  });

  final double value;
  final double step;
  final ValueChanged<double> onChanged;
  final String unit;
  final double min;
  final double? max;
  final int decimals;
  final VoidCallback? onTapValue;

  /// Title of the keypad sheet opened when [onTapValue] is null.
  final String? entryTitle;

  double _clamp(double v) {
    final hi = max;
    var out = v < min ? min : v;
    if (hi != null && out > hi) out = hi;
    return double.parse(out.toStringAsFixed(decimals < 4 ? 4 : decimals));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onTap = onTapValue ??
        () async {
          final v = await showNumberEntrySheet(
            context,
            title: entryTitle ?? (RegExp('[a-z]').hasMatch(unit) ? 'Enter $unit' : 'Enter a number'),
            initial: value,
            unit: unit,
            decimals: decimals,
            min: min,
            max: max,
          );
          if (v != null) onChanged(_clamp(v));
        };
    final shown = Fmt.number(value, maxDecimals: decimals);
    Widget button(IconData icon, String tooltip, double? next) => SizedBox.square(
          dimension: Sizes.stepper,
          child: IconButton.filledTonal(
            tooltip: tooltip,
            iconSize: 32,
            style: IconButton.styleFrom(
              backgroundColor: t.surface2,
              foregroundColor: t.onSurface,
              disabledBackgroundColor: t.surface2.withValues(alpha: 0.5),
              disabledForegroundColor: t.muted.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
            ),
            onPressed: next == null ? null : () => onChanged(next),
            icon: Icon(icon),
          ),
        );
    final canDown = value - step >= min - 1e-9;
    final canUp = max == null || value + step <= max! + 1e-9;
    return Row(
      children: [
        button(Icons.remove, 'Less', canDown ? _clamp(value - step) : null),
        const SizedBox(width: Space.s),
        Expanded(
          child: Semantics(
            label: '$shown $unit',
            hint: 'Tap to type a number',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.button),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.stepper),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: shown, style: AppText.value),
                        if (unit.isNotEmpty) TextSpan(text: ' $unit', style: AppText.label.copyWith(color: t.muted)),
                      ]),
                      style: TextStyle(color: t.onSurface),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.s),
        button(Icons.add, 'More', canUp ? _clamp(value + step) : null),
      ],
    );
  }
}
