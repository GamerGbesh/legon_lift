/// UI-side value types shared by stores and features (SPEC 7.2). Frozen after Phase 0.
library;

import 'package:flutter/foundation.dart';

import '../core/equality.dart';
import '../data/models/models.dart';
import '../domain/api.dart';

/// Everything onboarding collected; `ProfileStore.completeOnboarding` saves it.
@immutable
class OnboardingResult {
  const OnboardingResult({required this.profile, required this.settings, required this.templateId});

  final UserProfile profile;
  final AppSettings settings;

  /// Program chosen via `Personalization.programIdFor` (or the split picker).
  final String templateId;
}

/// Library search and filters (SPEC 4.6). Muscle chip groups (Back = lats + upper back ...) are
/// expanded by the UI into [muscles].
@immutable
class LibraryQuery {
  const LibraryQuery({
    this.text = '',
    this.muscles = const {},
    this.equipment = const {},
    this.beginnerOnly = true,
    this.showAllEquipment = false,
    this.favoritesOnly = false,
  });

  /// Default: "Beginner friendly" on, only ticked equipment.
  static const LibraryQuery initial = LibraryQuery();

  final String text;
  final Set<Muscle> muscles;
  final Set<Equipment> equipment;
  final bool beginnerOnly, showAllEquipment, favoritesOnly;

  LibraryQuery copyWith({
    String? text,
    Set<Muscle>? muscles,
    Set<Equipment>? equipment,
    bool? beginnerOnly,
    bool? showAllEquipment,
    bool? favoritesOnly,
  }) =>
      LibraryQuery(
        text: text ?? this.text,
        muscles: muscles ?? this.muscles,
        equipment: equipment ?? this.equipment,
        beginnerOnly: beginnerOnly ?? this.beginnerOnly,
        showAllEquipment: showAllEquipment ?? this.showAllEquipment,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      );

  List<Object?> get _props => [text, muscles, equipment, beginnerOnly, showAllEquipment, favoritesOnly];
  @override
  bool operator ==(Object other) => other is LibraryQuery && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A suggestion card on Today (SPEC 4.3).
@immutable
sealed class TodayCard {
  const TodayCard();
}

/// "Easy week?" reactive deload suggestion (accept -> `ProgramStore.acceptReactiveDeload`).
final class DeloadCard extends TodayCard {
  const DeloadCard({this.reasons = const []});
  final List<String> reasons;
}

/// Weekly calorie check-in (SPEC 10.2).
final class CheckinCard extends TodayCard {
  const CheckinCard(this.advice);
  final CheckinAdvice advice;
}

/// A milestone just earned.
final class MilestoneCard extends TodayCard {
  const MilestoneCard(this.milestone);
  final Milestone milestone;
}

/// "Try a variation?" after two -10% resets on [exerciseId].
final class VariationCard extends TodayCard {
  const VariationCard(this.exerciseId);
  final String exerciseId;
}

/// Yearly PAR-Q re-check.
final class ParqRecheckCard extends TodayCard {
  const ParqRecheckCard();
}

/// Daily tip from `personalization.tips`.
final class TipCard extends TodayCard {
  const TipCard(this.text);
  final String text;
}
