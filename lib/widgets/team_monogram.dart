import 'package:flutter/material.dart';

import '../core/hex.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Monogramme d'équipe — carré aux couleurs du club, initiales en Archivo.
///
/// Aucune image : le jeu de données ne fournit pas de logo, seulement
/// `short_name` et trois couleurs par équipe.
class TeamMonogram extends StatelessWidget {
  const TeamMonogram({super.key, required this.team, this.size = 32});

  /// Variante agrandie utilisée dans l'en-tête de l'écran E3.
  const TeamMonogram.large({super.key, required this.team}) : size = 52;

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = team.shortName.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorFromHex(team.colorPrimary, fallback: AppColors.tribune2),
        borderRadius: const BorderRadius.all(AppRadii.monogram),
        border: Border.all(color: AppColors.ligne),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.42,
              color: colorFromHex(team.colorText, fallback: AppColors.craie),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
