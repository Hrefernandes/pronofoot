/// Conversion des couleurs `#RRGGBB` stockées en base vers `Color`.
library;

import 'package:flutter/painting.dart';

/// Parse une chaîne `#RRGGBB` (format garanti par la base : `char(7)`).
///
/// Renvoie [fallback] si la chaîne est nulle ou malformée, pour ne jamais
/// faire planter un rendu à cause d'une donnée douteuse.
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF7C89A8)}) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return fallback;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
