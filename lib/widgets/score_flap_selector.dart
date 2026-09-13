import 'package:flutter/material.dart';

import '../core/text_metrics.dart';
import '../core/theme.dart';

/// Sélecteur de score en volets — élément signature de l'écran E3.
///
/// Deux tuiles « panneau d'aéroport », chacune pilotée par des boutons − / +.
/// Choix assumé face à un `TextField` : le geste se fait au pouce, d'une main,
/// sans masquer l'écran avec un clavier. Le score est borné 0..20 (CHECK base).
class ScoreFlapSelector extends StatelessWidget {
  const ScoreFlapSelector({
    super.key,
    required this.homeScore,
    required this.awayScore,
    required this.homeLabel,
    required this.awayLabel,
    required this.onChanged,
    required this.lockLabel,
    this.enabled = true,
  });

  static const int minScore = 0;
  static const int maxScore = 20;

  final int homeScore;
  final int awayScore;
  final String homeLabel;
  final String awayLabel;

  /// Rappelé avec le couple complet à chaque incrément.
  final void Function(int home, int away) onChanged;

  /// Texte de la barre de verrouillage (« Modifiable jusqu'à 21:00 »).
  final String lockLabel;
  final bool enabled;

  void _bump({required bool isHome, required int delta}) {
    if (!enabled) return;
    final next = ((isHome ? homeScore : awayScore) + delta).clamp(
      minScore,
      maxScore,
    );
    onChanged(isHome ? next : homeScore, isHome ? awayScore : next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Stepper(
              value: homeScore,
              label: homeLabel,
              enabled: enabled,
              onDecrement: () => _bump(isHome: true, delta: -1),
              onIncrement: () => _bump(isHome: true, delta: 1),
            ),
            const SizedBox(width: AppSpacing.m),
            _Stepper(
              value: awayScore,
              label: awayLabel,
              enabled: enabled,
              onDecrement: () => _bump(isHome: false, delta: -1),
              onIncrement: () => _bump(isHome: false, delta: 1),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        _LockBar(label: lockLabel),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final String label;
  final bool enabled;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FlapTile(value: value),
        const SizedBox(height: AppSpacing.s),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlapButton(
              icon: Icons.remove,
              onPressed: enabled && value > ScoreFlapSelector.minScore
                  ? onDecrement
                  : null,
            ),
            const SizedBox(width: AppSpacing.s),
            _FlapButton(
              icon: Icons.add,
              onPressed: enabled && value < ScoreFlapSelector.maxScore
                  ? onIncrement
                  : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 74,
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppText.eyebrow.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Tuile 74 × 88 façon panneau d'aéroport : dégradé haut / bas, filet central.
class _FlapTile extends StatelessWidget {
  const _FlapTile({required this.value});

  static const double _width = 74;
  static const double _height = 88;

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadii.allM,
        border: Border.all(color: AppColors.ligne),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.tribune2, AppColors.tribune],
          stops: [0.499, 0.501],
        ),
      ),
      child: Stack(
        children: [
          // Filet central, positionné en dur : ne dépend d'aucune métrique
          // de police (contrairement à un centrage par Stack/Text).
          const Positioned(
            top: _height / 2,
            left: 0,
            right: 0,
            child: Divider(height: 1, thickness: 1),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.vertical,
                  child: child,
                ),
              ),
              child: _CenteredDigit(
                key: ValueKey<int>(value),
                value: value,
                boxHeight: _height,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chiffre positionné sur son centre optique réel (l'encre du glyphe),
/// mesuré via [TextPainter], plutôt que sur le centre de la boîte de ligne
/// de la police — laquelle réserve pour la plupart des polices un espace
/// sous la ligne de base (pour les jambages) qui n'existe pas sur un
/// chiffre, et fait paraître le texte décalé vers le haut si on se contente
/// d'un centrage `Alignment.center` classique.
class _CenteredDigit extends StatelessWidget {
  const _CenteredDigit({
    super.key,
    required this.value,
    required this.boxHeight,
  });

  final int value;
  final double boxHeight;

  @override
  Widget build(BuildContext context) {
    final text = '$value';
    final painter = TextPainter(
      text: TextSpan(text: text, style: AppText.flapScore),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = centeredTextOffset(painter, boxHeight);

    return Stack(
      children: [
        Positioned(
          top: dy,
          left: 0,
          right: 0,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.flapScore,
          ),
        ),
      ],
    );
  }
}

/// Bouton − / + de 30 × 26.
class _FlapButton extends StatelessWidget {
  const _FlapButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    return Material(
      color: active ? AppColors.tribune2 : AppColors.tribune,
      borderRadius: AppRadii.allS,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.allS,
        child: Container(
          width: 30,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.allS,
            border: Border.all(color: AppColors.ligne),
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? AppColors.craie : AppColors.ardoise,
          ),
        ),
      ),
    );
  }
}

class _LockBar extends StatelessWidget {
  const _LockBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock, size: 12, color: AppColors.ardoise),
        const SizedBox(width: AppSpacing.s),
        Text(label, style: AppText.bodyMuted),
      ],
    );
  }
}
