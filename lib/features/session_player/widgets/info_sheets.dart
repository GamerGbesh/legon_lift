// Owner: WS3. How-to sheet and plate calculator sheet (SPEC 4.4).
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/models/models.dart';
import '../../../domain/api.dart';
import '../../../services/api.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/number_entry_sheet.dart';
import '../../../widgets/number_stepper.dart';
import 'exercise_media.dart';
import 'player_copy.dart';

/// Opens [ex]'s video outside the app; tells the user when nothing could open (offline).
Future<void> openVideo(BuildContext context, LauncherService launcher, Exercise ex) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await launcher.openVideo(ex);
  if (!ok) {
    messenger?.showSnackBar(const SnackBar(content: Text("Couldn't open the video. It needs an internet connection.")));
  }
}

/// Setup steps, cues, mistakes, breathing, safety and the video button.
Future<void> showHowToSheet(BuildContext context, Exercise ex, LauncherService launcher) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _HowToSheet(exercise: ex, launcher: launcher),
    );

class _HowToSheet extends StatelessWidget {
  const _HowToSheet({required this.exercise, required this.launcher});

  final Exercise exercise;
  final LauncherService launcher;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ex = exercise;
    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: PlayerText.strong(AppText.body).copyWith(color: t.primary, fontSize: 18)),
              ),
              const SizedBox(height: Space.s),
              ...children,
            ],
          ),
        );
    Widget line(String text, {String? lead, Color? leadColor}) => Padding(
          padding: const EdgeInsets.only(bottom: Space.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(lead ?? '•', style: PlayerText.strong(AppText.body).copyWith(color: leadColor ?? t.muted)),
              ),
              Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
            ],
          ),
        );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
        children: [
          ExerciseMedia(exercise: ex, large: true),
          const SizedBox(height: Space.l),
          Text(ex.name, style: PlayerText.exerciseName.copyWith(color: t.onSurface)),
          if (ex.setup.isNotEmpty)
            section('Set up', [for (final (i, s) in ex.setup.indexed) line(s, lead: '${i + 1}.', leadColor: t.primary)]),
          if (ex.cues.isNotEmpty) section('While you lift', [for (final c in ex.cues) line(c)]),
          if (ex.mistakes.isNotEmpty)
            section('Common mistakes', [for (final m in ex.mistakes) line(m, lead: '✕', leadColor: t.warning)]),
          if (ex.breathing.isNotEmpty) section('Breathing', [line(ex.breathing)]),
          if (ex.safety.isNotEmpty) section('Safety', [line(ex.safety, lead: '!', leadColor: t.danger)]),
          const SizedBox(height: Space.xl),
          BigButton(
            label: 'Watch video',
            icon: Icons.play_circle_outline,
            kind: BigButtonKind.secondary,
            height: Sizes.minTap,
            onPressed: () => openVideo(context, launcher, ex),
          ),
          const SizedBox(height: Space.s),
          Text('Opens YouTube. Needs internet.',
              textAlign: TextAlign.center, style: AppText.label.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

/// Plate calculator. Returns a total the user chose to use (nearest achievable), or null.
Future<double?> showPlateSheet(
  BuildContext context, {
  required Exercise exercise,
  required double targetKg,
  required EquipmentProfile equipment,
}) =>
    showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PlateSheet(exercise: exercise, targetKg: targetKg, equipment: equipment),
    );

class _PlateSheet extends StatefulWidget {
  const _PlateSheet({required this.exercise, required this.targetKg, required this.equipment});

  final Exercise exercise;
  final double targetKg;
  final EquipmentProfile equipment;

  @override
  State<_PlateSheet> createState() => _PlateSheetState();
}

class _PlateSheetState extends State<_PlateSheet> {
  late double _target = widget.targetKg;
  late final Set<double> _plates = widget.equipment.platesKg.toSet();

  bool get _smith => widget.exercise.loadType == LoadType.smith;
  double get _bar => _smith ? widget.equipment.smithBarKg : widget.equipment.barKg;

  /// Standard plate colours (by kg) so the stack looks like the plates on the rack.
  static Color plateColor(double kg) => switch (kg) {
        >= 25 => const Color(0xFFE53935),
        >= 20 => const Color(0xFF1E63D6),
        >= 15 => const Color(0xFFF2C200),
        >= 10 => const Color(0xFF2E9E4F),
        >= 5 => const Color(0xFFF5F5F5),
        >= 2.5 => const Color(0xFF212121),
        _ => const Color(0xFFB0B7BF),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final plates = (_plates.toList()..sort((a, b) => b.compareTo(a)));
    final r = calculatePlates(_target, _bar, plates);
    final perSide = r.perSide;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plates', style: AppText.headline.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.m),
          Text('Total on the bar (including the bar)', style: AppText.label.copyWith(color: t.muted)),
          NumberStepper(
            value: _target,
            step: 2.5,
            min: _bar,
            unit: 'kg',
            onChanged: (v) => setState(() => _target = v),
          ),
          const SizedBox(height: Space.s),
          Text(
            _smith ? 'Smith bar: ${Fmt.weight(_bar)}' : 'Barbell: ${Fmt.weight(_bar)}',
            style: AppText.body.copyWith(color: t.onSurface),
          ),
          if (_smith && !widget.equipment.smithBarKnown)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                'Smith bar weight unknown: counting the bar as ${Fmt.weight(widget.equipment.smithBarKg)}.',
                style: AppText.label.copyWith(color: t.warning),
              ),
            ),
          const SizedBox(height: Space.xl),
          _PlateStack(perSide: perSide, colorOf: plateColor),
          const SizedBox(height: Space.m),
          Text(
            perSide.isEmpty ? 'Each side: no plates (just the bar)' : 'Each side: ${perSide.map(Fmt.number).join(' + ')}',
            textAlign: TextAlign.center,
            style: PlayerText.strong(AppText.body).copyWith(fontSize: 20, color: t.onSurface),
          ),
          if (!r.exact) ...[
            const SizedBox(height: Space.s),
            Text(
              "Can't make ${Fmt.weight(_target)} exactly with these plates.",
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: t.warning),
            ),
            const SizedBox(height: Space.m),
            Row(
              children: [
                if (r.lowerKg != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(r.lowerKg),
                      child: Text('Use ${Fmt.weight(r.lowerKg!)}'),
                    ),
                  ),
                if (r.lowerKg != null && r.higherKg != null) const SizedBox(width: Space.m),
                if (r.higherKg != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(r.higherKg),
                      child: Text('Use ${Fmt.weight(r.higherKg!)}'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.xl),
          Text('Plates you can use', style: AppText.label.copyWith(color: t.muted)),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final p in widget.equipment.platesKg.toSet().toList()..sort((a, b) => b.compareTo(a)))
                FilterChip(
                  label: Text('${Fmt.number(p)} kg'),
                  selected: _plates.contains(p),
                  onSelected: (on) => setState(() => on ? _plates.add(p) : _plates.remove(p)),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          BigButton(
            label: r.exact ? 'Use ${Fmt.weight(r.totalKg)}' : 'Close',
            onPressed: () => Navigator.of(context).pop(r.exact ? r.totalKg : null),
          ),
        ],
      ),
    );
  }
}

/// Leg press plate adder: tap the plates on ONE side, the sheet doubles it. Returns the total of
/// both sides (what the leg press logs; the sled is not counted), or null.
Future<double?> showSledPlatesSheet(
  BuildContext context, {
  required double currentKg,
  required EquipmentProfile equipment,
}) =>
    showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SledPlatesSheet(currentKg: currentKg, equipment: equipment),
    );

class _SledPlatesSheet extends StatefulWidget {
  const _SledPlatesSheet({required this.currentKg, required this.equipment});

  final double currentKg;
  final EquipmentProfile equipment;

  @override
  State<_SledPlatesSheet> createState() => _SledPlatesSheetState();
}

class _SledPlatesSheetState extends State<_SledPlatesSheet> {
  late final List<double> _side = _start();

  /// Starts from the current weight when the plates can make it, else from no plates.
  List<double> _start() {
    if (widget.currentKg <= 0) return [];
    final r = calculatePlates(widget.currentKg, 0, widget.equipment.platesKg);
    return r.exact ? [...r.perSide] : [];
  }

  double get _sideKg => double.parse(_side.fold<double>(0, (a, b) => a + b).toStringAsFixed(2));
  double get _totalKg => double.parse((_sideKg * 2).toStringAsFixed(2));

  void _add(double kg) => setState(() {
        _side
          ..add(kg)
          ..sort((a, b) => b.compareTo(a));
      });

  Future<void> _other() async {
    final v = await showNumberEntrySheet(context, title: 'Plate weight', initial: 0, unit: 'kg', decimals: 2, max: 50);
    if (v != null && v > 0) _add(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final plates = widget.equipment.platesKg.toSet().toList()..sort((a, b) => b.compareTo(a));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Leg press plates', style: AppText.headline.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.xs),
          Text('Tap the plates on ONE side. The app doubles it for you. Tap a plate in the list to remove it.',
              style: AppText.body.copyWith(color: t.muted)),
          const SizedBox(height: Space.l),
          _PlateStack(perSide: _side, colorOf: _PlateSheetState.plateColor),
          const SizedBox(height: Space.s),
          Text(
            _side.isEmpty
                ? 'Each side: no plates yet'
                : 'Each side: ${_side.map(Fmt.number).join(' + ')} = ${Fmt.weight(_sideKg)}',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: t.onSurface),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Total: ${Fmt.weight(_totalKg)}',
            textAlign: TextAlign.center,
            style: PlayerText.strong(AppText.headline).copyWith(color: t.primary),
          ),
          if (_side.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final (i, p) in _side.indexed)
                  InputChip(
                    label: Text('${Fmt.number(p)} kg'),
                    onDeleted: () => setState(() => _side.removeAt(i)),
                    deleteButtonTooltipMessage: 'Remove',
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.xl),
          Text('Add a plate (one side)', style: AppText.label.copyWith(color: t.muted)),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final p in plates)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text('${Fmt.number(p)} kg'),
                  onPressed: () => _add(p),
                ),
              ActionChip(
                avatar: const Icon(Icons.dialpad, size: 18),
                label: const Text('Other'),
                onPressed: () => unawaited(_other()),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          BigButton(
            label: 'Use ${Fmt.weight(_totalKg)}',
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(_totalKg),
          ),
        ],
      ),
    );
  }
}

/// One side of the bar: plates heaviest first, drawn from the sleeve outwards.
class _PlateStack extends StatelessWidget {
  const _PlateStack({required this.perSide, required this.colorOf});

  final List<double> perSide;
  final Color Function(double) colorOf;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxKg = perSide.isEmpty ? 25.0 : perSide.reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: perSide.isEmpty ? 'No plates' : 'Each side: ${perSide.map(Fmt.number).join(', ')} kilograms',
      child: SizedBox(
        height: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 14, color: t.muted),
            Container(width: 8, height: 36, color: t.muted),
            for (final p in perSide)
              Container(
                width: 18,
                height: 40 + 80 * (p / (maxKg < 20 ? 20 : maxKg)).clamp(0.2, 1.0),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: colorOf(p),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.bg, width: 1),
                ),
              ),
            Container(width: 48, height: 14, color: t.muted),
          ],
        ),
      ),
    );
  }
}
