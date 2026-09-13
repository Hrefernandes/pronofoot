import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/core/text_metrics.dart';

/// Le sélecteur de score (E3) affiche un gros chiffre censé être centré sur
/// le filet horizontal de la tuile. Un centrage `Alignment.center` naïf se
/// cale sur la boîte de ligne de la police (qui réserve de l'espace sous la
/// ligne de base pour des jambages qu'un chiffre n'a jamais), pas sur
/// l'encre réellement dessinée — d'où le décalage vers le haut observé.
void main() {
  TextPainter painterFor(String text, {double fontSize = 52}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  test('centre l\'encre du chiffre au milieu de la boîte, pas sa ligne', () {
    final painter = painterFor('8');
    const boxHeight = 88.0;

    final dy = centeredTextOffset(painter, boxHeight);

    // Après application du décalage, le centre de l'encre doit tomber
    // exactement au milieu de la zone — à l'arrondi de mesure près.
    final boxes = painter.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    final inkTop = boxes.map((b) => b.top).reduce((a, b) => a < b ? a : b);
    final inkBottom = boxes
        .map((b) => b.bottom)
        .reduce((a, b) => a > b ? a : b);
    final resultingCenter = (inkTop + dy + inkBottom + dy) / 2;

    expect(resultingCenter, closeTo(boxHeight / 2, 0.5));
  });

  test('reste correct pour une boîte plus petite ou plus grande', () {
    final painter = painterFor('12');
    for (final boxHeight in [40.0, 88.0, 160.0]) {
      final dy = centeredTextOffset(painter, boxHeight);
      final boxes = painter.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      final inkTop = boxes.map((b) => b.top).reduce((a, b) => a < b ? a : b);
      final inkBottom = boxes
          .map((b) => b.bottom)
          .reduce((a, b) => a > b ? a : b);
      expect((inkTop + dy + inkBottom + dy) / 2, closeTo(boxHeight / 2, 0.5));
    }
  });

  test('chaîne vide : ne plante pas, renvoie un décalage fini', () {
    final painter = painterFor('');
    expect(centeredTextOffset(painter, 88).isFinite, isTrue);
  });
}
