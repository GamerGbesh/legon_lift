// Owner: WS5. Plain-language muscle groups and equipment labels shared by the Library and Progress.
import 'package:material_ui/material_ui.dart';

import '../../data/models/models.dart';

/// A filter / chart group of muscles (SPEC 4.6: Back = lats + upper back, Shoulders = 3 delts,
/// Core = abs + obliques + lower back).
@immutable
class MuscleGroup {
  const MuscleGroup(this.label, this.muscles);

  final String label;
  final Set<Muscle> muscles;
}

/// The Library's muscle chips in display order (Mobility is a separate chip, see LibraryStore).
const List<MuscleGroup> muscleGroups = [
  MuscleGroup('Chest', {Muscle.chest}),
  MuscleGroup('Back', {Muscle.lats, Muscle.upperBack}),
  MuscleGroup('Shoulders', {Muscle.frontDelts, Muscle.sideDelts, Muscle.rearDelts}),
  MuscleGroup('Biceps', {Muscle.biceps}),
  MuscleGroup('Triceps', {Muscle.triceps}),
  MuscleGroup('Quads', {Muscle.quads}),
  MuscleGroup('Hamstrings', {Muscle.hamstrings}),
  MuscleGroup('Glutes', {Muscle.glutes}),
  MuscleGroup('Calves', {Muscle.calves}),
  MuscleGroup('Core', {Muscle.abs, Muscle.obliques, Muscle.lowerBack}),
  MuscleGroup('Cardio', {Muscle.cardio}),
];

/// Groups shown in "Hard sets per muscle" (no cardio).
List<MuscleGroup> get trainingGroups => [for (final g in muscleGroups) if (!g.muscles.contains(Muscle.cardio)) g];

/// Hard sets of [group] from per-muscle counts. The members of a group mostly share the same sets
/// (a row hits lats and upper back), so the group shows its busiest member instead of the sum.
double groupHardSets(MuscleGroup group, Map<Muscle, double> hardSets) {
  var best = 0.0;
  for (final m in group.muscles) {
    final v = hardSets[m] ?? 0;
    if (v > best) best = v;
  }
  return best;
}

/// Short display name of a piece of equipment (chips and rows).
String equipmentLabel(Equipment e) => switch (e) {
      Equipment.cable => 'Cable',
      Equipment.latPulldownMachine => 'Lat pulldown',
      Equipment.shoulderPressMachine => 'Shoulder press machine',
      Equipment.chestPressMachine => 'Chest press machine',
      Equipment.bike => 'Bike',
      Equipment.treadmill => 'Treadmill',
      Equipment.barbell => 'Barbell',
      Equipment.dumbbell => 'Dumbbells',
      Equipment.legPress => 'Leg press',
      Equipment.plates => 'Plates',
      Equipment.calfRaiseMachine => 'Calf raise machine',
      Equipment.legCurlMachine => 'Leg curl machine',
      Equipment.legExtensionMachine => 'Leg extension machine',
      Equipment.smithMachine => 'Smith machine',
      Equipment.bench => 'Bench',
      Equipment.bodyweight => 'Bodyweight',
      Equipment.ankleStrap => 'Ankle strap',
    };

/// The equipment that best describes [ex] in a list row ("Bike or treadmill", "Dumbbells").
String mainEquipmentLabel(Exercise ex) {
  final eq = ex.equipment;
  if (eq.contains(Equipment.bike) && eq.contains(Equipment.treadmill)) return 'Bike or treadmill';
  const order = [
    Equipment.smithMachine,
    Equipment.barbell,
    Equipment.legPress,
    Equipment.chestPressMachine,
    Equipment.shoulderPressMachine,
    Equipment.latPulldownMachine,
    Equipment.legCurlMachine,
    Equipment.legExtensionMachine,
    Equipment.calfRaiseMachine,
    Equipment.cable,
    Equipment.dumbbell,
    Equipment.bike,
    Equipment.treadmill,
    Equipment.bench,
    Equipment.bodyweight,
  ];
  for (final e in order) {
    if (eq.contains(e)) return equipmentLabel(e);
  }
  return eq.isEmpty ? 'No equipment' : equipmentLabel(eq.first);
}

/// Icon for [ex]'s main equipment.
IconData equipmentIcon(Exercise ex) {
  final eq = ex.equipment;
  if (eq.contains(Equipment.bike) || eq.contains(Equipment.treadmill)) return Icons.directions_bike;
  if (eq.contains(Equipment.cable)) return Icons.cable;
  if (eq.contains(Equipment.dumbbell) || eq.contains(Equipment.barbell) || eq.contains(Equipment.smithMachine)) {
    return Icons.fitness_center;
  }
  if (eq.any((e) => e.wire.endsWith('_machine') || e == Equipment.legPress)) return Icons.precision_manufacturing;
  if (ex.category == ExerciseCategory.mobility) return Icons.self_improvement;
  return Icons.accessibility_new;
}

/// "Beginner friendly" / "Medium" / "Harder" for difficulty 1 / 2 / 3.
String difficultyLabel(int difficulty) => switch (difficulty) {
      <= 1 => 'Beginner friendly',
      2 => 'Medium',
      _ => 'Harder',
    };
