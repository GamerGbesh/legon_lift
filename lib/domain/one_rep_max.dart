// Owner: WS2. Estimated best single (SPEC 6.11).

/// Estimated best single (Epley) for [totalKg] x [reps] (SPEC 6.11). [totalKg] is the total
/// external load of SPEC 0.4. A single is its own best; zero reps estimate nothing.
/// Callers use it only for sets of 12 reps or fewer (see [maxRepsForE1rm]).
double epley1rm(double totalKg, int reps) {
  if (reps <= 0 || totalKg <= 0) return 0;
  if (reps == 1) return totalKg;
  return totalKg * (1 + reps / 30);
}

/// Sets with more reps than this do not give an estimated best single (SPEC 6.11).
const int maxRepsForE1rm = 12;

/// Retest estimate (SPEC 6.6): the set stopped with about one rep left, so that rep counts.
double retestE1rm(double totalKg, int reps) => reps <= 0 || totalKg <= 0 ? 0 : totalKg * (1 + (reps + 1) / 30);
