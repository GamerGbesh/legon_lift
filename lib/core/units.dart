/// Unit conversion. Storage is always metric (SPEC 0.3); conversion happens only in the UI.
abstract final class Units {
  static const double kgPerLb = 0.45359237;
  static const double cmPerInch = 2.54;
  static const int inchesPerFoot = 12;

  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;

  static double cmToInches(double cm) => cm / cmPerInch;
  static double inchesToCm(double inches) => inches * cmPerInch;

  /// Splits a height in cm into whole feet and rounded inches (5 ft 8 in), carrying 12 in to 1 ft.
  static (int feet, int inches) cmToFtIn(double cm) {
    final total = cmToInches(cm).round();
    return (total ~/ inchesPerFoot, total % inchesPerFoot);
  }

  static double ftInToCm(int feet, int inches) => inchesToCm((feet * inchesPerFoot + inches).toDouble());

  /// A kg value in the user's display unit.
  static double displayWeight(double kg, {required bool useLb}) => useLb ? kgToLb(kg) : kg;

  /// A value typed in the user's display unit, back to kg.
  static double weightToKg(double value, {required bool useLb}) => useLb ? lbToKg(value) : value;

  static String weightUnit({required bool useLb}) => useLb ? 'lb' : 'kg';
}
