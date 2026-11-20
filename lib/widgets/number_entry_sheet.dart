// Owner: WS4. Shared helper (additive to SPEC 12.3): the numeric keypad sheet opened by tapping a
// NumberStepper value (SPEC 4.4 "Tapping a value opens a numeric keypad sheet").
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';
import '../core/format.dart';
import 'big_button.dart';

/// Shows a big-key numeric keypad and returns the typed number (null when dismissed).
/// Values outside [min]..[max] disable "Done" and show the allowed range.
Future<double?> showNumberEntrySheet(
  BuildContext context, {
  required String title,
  required double initial,
  required String unit,
  int decimals = 1,
  double min = 0,
  double? max,
}) =>
    showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NumberEntrySheet(
        title: title,
        initial: initial,
        unit: unit,
        decimals: decimals,
        min: min,
        max: max,
      ),
    );

class _NumberEntrySheet extends StatefulWidget {
  const _NumberEntrySheet({
    required this.title,
    required this.initial,
    required this.unit,
    required this.decimals,
    required this.min,
    required this.max,
  });

  final String title;
  final double initial;
  final String unit;
  final int decimals;
  final double min;
  final double? max;

  @override
  State<_NumberEntrySheet> createState() => _NumberEntrySheetState();
}

class _NumberEntrySheetState extends State<_NumberEntrySheet> {
  late String _text = Fmt.number(widget.initial, maxDecimals: widget.decimals);

  /// The first key press replaces the pre-filled value instead of appending to it.
  bool _fresh = true;

  double? get _value => double.tryParse(_text);

  bool get _valid {
    final v = _value;
    if (v == null) return false;
    final hi = widget.max;
    return v >= widget.min - 1e-9 && (hi == null || v <= hi + 1e-9);
  }

  void _press(String key) {
    setState(() {
      if (_fresh && key != '⌫') _text = '';
      _fresh = false;
      if (key == '⌫') {
        _text = _text.isEmpty ? '' : _text.substring(0, _text.length - 1);
        return;
      }
      if (key == '.') {
        if (widget.decimals == 0 || _text.contains('.')) return;
        _text = _text.isEmpty ? '0.' : '$_text.';
        return;
      }
      final dot = _text.indexOf('.');
      if (dot >= 0 && _text.length - dot - 1 >= widget.decimals) return;
      if (_text.replaceAll('.', '').length >= 6) return;
      _text = _text == '0' ? key : '$_text$key';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hi = widget.max;
    final range = hi == null
        ? 'At least ${Fmt.number(widget.min)} ${widget.unit}'
        : '${Fmt.number(widget.min)}–${Fmt.number(hi)} ${widget.unit}';
    Widget key(String label, {String? semantics}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: SizedBox(
              height: Sizes.stepper,
              child: Semantics(
                label: semantics ?? label,
                button: true,
                excludeSemantics: true,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.surface2,
                    foregroundColor: t.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                  ),
                  onPressed: label == '.' && widget.decimals == 0 ? null : () => _press(label),
                  child: label == '⌫'
                      ? const Icon(Icons.backspace_outlined, size: 28)
                      : Text(label, style: AppText.value.copyWith(fontSize: 30)),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppText.title.copyWith(color: t.onSurface), textAlign: TextAlign.center),
          const SizedBox(height: Space.m),
          Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(Radii.button),
              border: Border.all(color: _valid || _text.isEmpty ? t.surface2 : t.warning, width: 2),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: _text.isEmpty ? '0' : _text, style: AppText.value.copyWith(fontSize: 48)),
                TextSpan(text: ' ${widget.unit}', style: AppText.body.copyWith(color: t.muted)),
              ]),
              style: TextStyle(color: _text.isEmpty ? t.muted : t.onSurface),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(range, textAlign: TextAlign.center, style: AppText.label.copyWith(color: _valid ? t.muted : t.warning)),
          const SizedBox(height: Space.s),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['.', '0', '⌫'],
          ])
            Row(children: [for (final k in row) key(k, semantics: k == '⌫' ? 'Delete' : (k == '.' ? 'Decimal point' : null))]),
          const SizedBox(height: Space.m),
          BigButton(
            label: 'Done',
            icon: Icons.check,
            onPressed: _valid ? () => Navigator.of(context).pop(_value) : null,
          ),
        ],
      ),
    );
  }
}
