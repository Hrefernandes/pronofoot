/// Barème de points — RG-03, côté client.
///
/// Sert **uniquement à l'affichage prévisionnel** (écran E3, sous le
/// sélecteur). Le calcul qui fait foi est la fonction serveur `compute_points`,
/// déclenchée quand un match passe à `finished` ; ce qui est écrit en base
/// n'est jamais produit ici.
library;

/// Issue d'un match du point de vue d'un pronostic.
enum PredictionOutcome {
  /// Score exact.
  exact,

  /// Bon vainqueur / bon nul, score inexact.
  correctResult,

  /// Ni l'un ni l'autre.
  wrong,
}

/// Compare un pronostic `home-away` au score réel `actualHome-actualAway`.
PredictionOutcome outcomeOf({
  required int predHome,
  required int predAway,
  required int actualHome,
  required int actualAway,
}) {
  if (predHome == actualHome && predAway == actualAway) {
    return PredictionOutcome.exact;
  }
  final predSign = (predHome - predAway).sign;
  final actualSign = (actualHome - actualAway).sign;
  return predSign == actualSign
      ? PredictionOutcome.correctResult
      : PredictionOutcome.wrong;
}

/// Points rapportés par un pronostic selon le barème du groupe (RG-03, RG-04).
///
/// - score exact → [pointsExact]
/// - bon résultat → [pointsResult]
/// - sinon → 0
int computePoints({
  required int predHome,
  required int predAway,
  required int actualHome,
  required int actualAway,
  required int pointsExact,
  required int pointsResult,
}) {
  return switch (outcomeOf(
    predHome: predHome,
    predAway: predAway,
    actualHome: actualHome,
    actualAway: actualAway,
  )) {
    PredictionOutcome.exact => pointsExact,
    PredictionOutcome.correctResult => pointsResult,
    PredictionOutcome.wrong => 0,
  };
}
