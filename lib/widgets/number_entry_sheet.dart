// Owner: WS4. Shared helper (additive to SPEC 12.3): the numeric keypad sheet opened by tapping a
// NumberStepper value (SPEC 4.4 "Tapping a value opens a numeric keypad sheet"), with + − × ÷.
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';
import '../core/format.dart';
import 'big_button.dart';

/// Shows a big-key numeric keypad with + − × ÷ (worked out left to right) and returns the result
/// (null when dismissed).
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

  static const _ops = '+−×÷';

  bool get _hasOp => _text.split('').any(_ops.contains);

  /// The current number being typed (after the last operator).
  String get _operand {
    var i = _text.length - 1;
    while (i >= 0 && !_ops.contains(_text[i])) {
      i--;
    }
    return _text.substring(i + 1);
  }

  /// Evaluates the typed sum left to right, like a simple calculator ("25+11.3×2" = 72.6).
  /// A trailing operator is ignored; dividing by zero gives null.
  double? get _value {
    final parts = RegExp(r'[0-9.]+|[+−×÷]').allMatches(_text).map((m) => m[0]!).toList();
    if (parts.isNotEmpty && _ops.contains(parts.last)) parts.removeLast();
    if (parts.isEmpty) return null;
    var acc = double.tryParse(parts.first);
    for (var i = 1; i + 1 < parts.length && acc != null; i += 2) {
      final n = double.tryParse(parts[i + 1]);
      if (n == null) return null;
      acc = switch (parts[i]) {
        '+' => acc + n,
        '−' => acc - n,
        '×' => acc * n,
        _ => n == 0 ? null : acc / n,
      };
    }
    return acc == null ? null : double.parse(acc.toStringAsFixed(widget.decimals));
  }

  bool get _valid {
    final v = _value;
    if (v == null) return false;
    final hi = widget.max;
    return v >= widget.min - 1e-9 && (hi == null || v <= hi + 1e-9);
  }

  void _press(String key) {
    setState(() {
      final op = _ops.contains(key);
      // The first key replaces the pre-filled value, except an operator, which works on it.
      if (_fresh && key != '⌫' && !op) _text = '';
      _fresh = false;
      if (key == '⌫') {
        _text = _text.isEmpty ? '' : _text.substring(0, _text.length - 1);
        return;
      }
      if (op) {
        if (_text.isEmpty) return;
        final last = _text[_text.length - 1];
        if (_ops.contains(last)) {
          _text = '${_text.substring(0, _text.length - 1)}$key';
        } else {
          if (last == '.') _text = _text.substring(0, _text.length - 1);
          _text = '$_text$key';
        }
        return;
      }
      final cur = _operand;
      final head = _text.substring(0, _text.length - cur.length);
      if (key == '.') {
        // Decimals allowed mid-sum even for whole-number fields (e.g. 25÷2.5); the result is rounded.
        if (cur.contains('.') || (widget.decimals == 0 && !_hasOp)) return;
        _text = '$head${cur.isEmpty ? '0.' : '$cur.'}';
        return;
      }
      final dot = cur.indexOf('.');
      if (dot >= 0 && cur.length - dot - 1 >= (_hasOp && widget.decimals < 2 ? 2 : widget.decimals)) return;
      if (cur.replaceAll('.', '').length >= 6) return;
      if (_text.length >= 24) return;
      _text = '$head${cur == '0' ? key : '$cur$key'}';
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
                  onPressed: label == '.' && widget.decimals == 0 && !_hasOp ? null : () => _press(label),
                  child: label == '⌫'
                      ? const Icon(Icons.backspace_outlined, size: 28)
                      : Text(label,
                          style: AppText.value
                              .copyWith(fontSize: 30, color: _ops.contains(label) ? t.primary : null)),
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
            padding: const EdgeInsets.symmetric(horizontal: Space.m),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: _text.isEmpty ? '0' : _text, style: AppText.value.copyWith(fontSize: 48)),
                  if (!_hasOp) TextSpan(text: ' ${widget.unit}', style: AppText.body.copyWith(color: t.muted)),
                ]),
                style: TextStyle(color: _text.isEmpty ? t.muted : t.onSurface),
                maxLines: 1,
              ),
            ),
          ),

          const SizedBox(height: Space.xs),
          // While a sum is typed this line shows its result (and the range when it is out of range).
          _hasOp
              ? Text(
                  _value == null
                      ? '= ?'
                      : '= ${Fmt.number(_value!, maxDecimals: widget.decimals)} ${widget.unit}'
                          '${_valid ? '' : '  ($range)'}',
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(fontWeight: FontWeight.w700).copyWith(color: _valid ? t.primary : t.warning),
                )
              : Text(range,
                  textAlign: TextAlign.center, style: AppText.label.copyWith(color: _valid ? t.muted : t.warning)),
          const SizedBox(height: Space.s),
          for (final row in const [
            ['1', '2', '3', '÷'],
            ['4', '5', '6', '×'],
            ['7', '8', '9', '−'],
            ['.', '0', '⌫', '+'],
          ])
            Row(children: [
              for (final k in row)
                key(k,
                    semantics: switch (k) {
                      '⌫' => 'Delete',
                      '.' => 'Decimal point',
                      '÷' => 'Divide',
                      '×' => 'Times',
                      '−' => 'Minus',
                      '+' => 'Plus',
                      _ => null,
                    }),
            ]),
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
