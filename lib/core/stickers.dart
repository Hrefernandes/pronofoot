/// Catalogue des stickers — icônes Material embarquées dans Flutter,
/// teintées à la volée. Remplace les avatars emoji : rendu identique sur
/// toutes les plateformes, aucune image, aucune dépendance.
///
/// La base ne stocke que le code du sticker (`avatar_icon`) et sa couleur
/// (`avatar_color`) : la couleur du symbole lui-même n'est jamais stockée,
/// elle est recalculée par luminance pour garantir le contraste (voir
/// [stickerForegroundColor]) — une troisième valeur en base pourrait devenir
/// incohérente avec les deux autres.
///
/// Un code inconnu de l'application retombe silencieusement sur le premier
/// sticker du catalogue : ajouter un sticker ne doit jamais nécessiter de
/// migration côté client existant.
library;

import 'package:flutter/material.dart';

class StickerDef {
  const StickerDef(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;
}

abstract final class Stickers {
  static const List<StickerDef> football = [
    StickerDef('ball', 'Ballon', Icons.sports_soccer),
    StickerDef('trophy', 'Trophée', Icons.emoji_events),
    StickerDef('medal', 'Médaille', Icons.military_tech),
    StickerDef('whistle', 'Sifflet', Icons.sports),
    StickerDef('stadium', 'Stade', Icons.stadium),
    StickerDef('flag', 'Drapeau', Icons.flag),
    StickerDef('timer', 'Chrono', Icons.timer),
    StickerDef('target', 'Cible', Icons.gps_fixed),
  ];

  static const List<StickerDef> animaux = [
    StickerDef('paw', 'Patte', Icons.pets),
    StickerDef('bug', 'Insecte', Icons.bug_report),
    StickerDef('bird', 'Oiseau', Icons.flutter_dash),
    StickerDef('egg', 'Œuf', Icons.egg),
  ];

  static const List<StickerDef> symboles = [
    StickerDef('fire', 'Flamme', Icons.local_fire_department),
    StickerDef('bolt', 'Éclair', Icons.bolt),
    StickerDef('star', 'Étoile', Icons.star),
    StickerDef('shield', 'Bouclier', Icons.shield),
    StickerDef('crown', 'Couronne', Icons.workspace_premium),
    StickerDef('diamond', 'Diamant', Icons.diamond),
    StickerDef('rocket', 'Fusée', Icons.rocket_launch),
    StickerDef('brain', 'Cerveau', Icons.psychology),
    StickerDef('dice', 'Dé', Icons.casino),
    StickerDef('snow', 'Flocon', Icons.ac_unit),
    StickerDef('heart', 'Cœur', Icons.favorite),
    StickerDef('sparkle', 'Étincelle', Icons.auto_awesome),
  ];

  static const List<StickerDef> all = [...football, ...animaux, ...symboles];

  /// Palette de fond sélectionnable. `exact` (#5CE28A) en est volontairement
  /// exclue : cette couleur est réservée au badge « score exact ».
  static const List<String> colors = [
    '#FFB020',
    '#34D399',
    '#4EA8FF',
    '#FF6B6B',
    '#C084FC',
    '#FF8FAB',
    '#2DD4BF',
    '#FB923C',
    '#A3E635',
    '#60A5FA',
    '#F472B6',
    '#94A3B8',
  ];

  static StickerDef byCode(String? code) =>
      all.firstWhere((s) => s.code == code, orElse: () => all.first);
}

/// Couleur du symbole sur un fond donné — jamais stockée, toujours
/// recalculée à partir du fond.
///
/// Formule classique de luminance perçue (0.299 R + 0.587 G + 0.114 B,
/// canaux entre 0 et 1) : un fond clair reçoit un symbole sombre, un fond
/// sombre reçoit un symbole clair.
Color stickerForegroundColor(Color background) {
  final luminance =
      0.299 * background.r + 0.587 * background.g + 0.114 * background.b;
  return luminance > 0.5 ? const Color(0xFF0B1220) : const Color(0xFFF2F5FF);
}
