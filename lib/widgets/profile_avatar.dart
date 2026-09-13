import 'package:flutter/material.dart';

import '../core/hex.dart';
import '../core/stickers.dart';
import '../core/theme.dart';

/// Avatar d'un membre : pastille ronde pleine, sticker Material + couleur
/// issus de `avatar_icon` / `avatar_color`. La couleur du symbole n'est
/// jamais stockée : elle est recalculée par contraste (voir [Stickers]).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.size = 34,
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
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(
        Stickers.byCode(icon).icon,
        size: size * 0.52,
        color: stickerForegroundColor(background),
      ),
    );
  }
}
