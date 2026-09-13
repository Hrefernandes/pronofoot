/// Centrage de texte sur son encre réelle plutôt que sur la boîte de ligne
/// de la police.
///
/// La plupart des polices réservent, sous la ligne de base, un espace pour
/// les jambages (g, y, p...) qui n'existe pas sur un chiffre : un centrage
/// `Alignment.center` classique fait alors paraître un gros chiffre décalé
/// vers le haut de sa boîte — visible sur le sélecteur de score (E3), où
/// l'écart est amplifié par la grande taille de police. `centeredTextOffset`
/// mesure l'encre réellement dessinée (via [TextPainter.getBoxesForSelection])
/// pour calculer le décalage qui centre vraiment le glyphe.
library;

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Décalage vertical (à ajouter à la position du haut du texte) pour que le
/// centre de son encre tombe au milieu d'une zone de hauteur [boxHeight].
///
/// [painter] doit déjà avoir été mis en page (`layout()` appelé).
double centeredTextOffset(TextPainter painter, double boxHeight) {
  final length = painter.text?.toPlainText().length ?? 0;
  final boxes = length == 0
      ? const <TextBox>[]
      : painter.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: length),
          boxHeightStyle: ui.BoxHeightStyle.tight,
        );

  double inkTop = 0;
  double inkBottom = painter.height;
  if (boxes.isNotEmpty) {
    inkTop = boxes.map((b) => b.top).reduce((a, b) => a < b ? a : b);
    inkBottom = boxes.map((b) => b.bottom).reduce((a, b) => a > b ? a : b);
  }

  final inkCenter = (inkTop + inkBottom) / 2;
  return boxHeight / 2 - inkCenter;
}
