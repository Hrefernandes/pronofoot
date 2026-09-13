import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Wordmark « PRONO·FOOT » — Archivo 800, capitales, seconde moitié en or.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 40});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      letterSpacing: -1,
      height: 1,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'PRONO',
            style: base.copyWith(color: AppColors.craie),
          ),
          TextSpan(
            text: 'FOOT',
            style: base.copyWith(color: AppColors.or),
          ),
        ],
      ),
    );
  }
}
