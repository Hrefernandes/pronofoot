import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/core/scoring.dart';

/// RG-03 / RG-04 — barème de points. Fonction pure, cœur du fil rouge
/// « saisir un pronostic ».
void main() {
  group('outcomeOf', () {
    test('score identique → exact', () {
      expect(
        outcomeOf(predHome: 2, predAway: 1, actualHome: 2, actualAway: 1),
        PredictionOutcome.exact,
      );
    });

    test('bon vainqueur, score différent → correctResult', () {
      expect(
        outcomeOf(predHome: 2, predAway: 1, actualHome: 3, actualAway: 0),
        PredictionOutcome.correctResult,
      );
    });

    test('nul prédit, nul réel sur un autre score → correctResult', () {
      expect(
        outcomeOf(predHome: 0, predAway: 0, actualHome: 2, actualAway: 2),
        PredictionOutcome.correctResult,
      );
    });

    test('mauvais vainqueur → wrong', () {
      expect(
        outcomeOf(predHome: 2, predAway: 1, actualHome: 0, actualAway: 1),
        PredictionOutcome.wrong,
      );
    });

    test('nul prédit, victoire réelle → wrong', () {
      expect(
        outcomeOf(predHome: 1, predAway: 1, actualHome: 2, actualAway: 1),
        PredictionOutcome.wrong,
      );
    });
  });

  group('computePoints avec barème 3 / 1 / 0', () {
    int points(int ph, int pa, int ah, int aa) => computePoints(
      predHome: ph,
      predAway: pa,
      actualHome: ah,
      actualAway: aa,
      pointsExact: 3,
      pointsResult: 1,
    );

    test('score exact rapporte points_exact', () {
      expect(points(2, 1, 2, 1), 3);
    });

    test('bon résultat rapporte points_result', () {
      expect(points(2, 1, 4, 2), 1);
    });

    test('pronostic raté rapporte 0', () {
      expect(points(2, 1, 1, 3), 0);
    });
  });

  test('barème paramétrable par groupe (RG-04)', () {
    expect(
      computePoints(
        predHome: 1,
        predAway: 0,
        actualHome: 1,
        actualAway: 0,
        pointsExact: 5,
        pointsResult: 2,
      ),
      5,
    );
    expect(
      computePoints(
        predHome: 1,
        predAway: 0,
        actualHome: 3,
        actualAway: 2,
        pointsExact: 5,
        pointsResult: 2,
      ),
      2,
    );
  });
}
