import 'package:flutter/material.dart';

import '../core/hex.dart';
import '../core/stickers.dart';
import '../core/theme.dart';

/// Sticker d'un groupe : carré arrondi plein, même logique que
/// [ProfileAvatar] mais en carré pour distinguer visuellement un groupe
/// d'un membre.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  final String icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = colorFromHex(color, fallback: AppColors.or);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Stickers.byCode(icon).icon,
        size: size * 0.52,
        color: stickerForegroundColor(background),
      ),
    );
  }
}
