import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Petite étiquette d'état. Voir les variantes nommées.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.dot = false,
  });

  /// À pronostiquer — accent or.
  const StatusBadge.toPredict({super.key})
    : label = 'À pronostiquer',
      color = AppColors.or,
      dot = true;

  /// Pronostic enregistré — neutre.
  const StatusBadge.saved({super.key})
    : label = 'Enregistré',
      color = AppColors.ardoise,
      dot = false;

  /// Score exact trouvé — vert réservé.
  const StatusBadge.exact({super.key})
    : label = 'Score exact',
      color = AppColors.exact,
      dot = false;

  /// Match en direct — or + pastille.
  const StatusBadge.live({super.key, String minute = 'Direct'})
    : label = minute,
      color = AppColors.or,
      dot = true;

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
