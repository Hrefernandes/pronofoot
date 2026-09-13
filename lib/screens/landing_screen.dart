import 'package:flutter/material.dart';

import '../app.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/wordmark.dart';

/// E0 — Landing page. Contenu statique de démonstration : le rôle `anon` n'a
/// aucun accès aux données réelles.
///
/// Anime une entrée en fondu/glissement au premier affichage (aucun paquet
/// externe : uniquement `AnimationController` + `Curves`, déjà fournis par
/// Flutter).
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  // Pastille « live » : pulsation continue, indépendante de l'entrée.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  static const _features = [
    (Icons.bolt, 'Prono en 30 secondes, au pouce'),
    (Icons.emoji_events, 'Classement automatique, sans tableur'),
    (Icons.lock, "Verrou au coup d'envoi — zéro triche"),
    (Icons.groups, 'Autant de groupes que d\'amis, un seul geste par match'),
  ];

  static const _steps = [
    (
      '1',
      Icons.group_add,
      'Crée ou rejoins un groupe avec un code à 6 caractères',
    ),
    (
      '2',
      Icons.sports_soccer,
      'Pronostique le score exact avant le coup d\'envoi',
    ),
    (
      '3',
      Icons.leaderboard,
      'Le classement se met à jour tout seul, match après match',
    ),
  ];

  static const _preview = [
    (1, Icons.local_fire_department, 'Marion', 41),
    (2, Icons.sports_soccer, 'Tom', 34),
    (3, Icons.pets, 'Kevin', 31),
  ];

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Fait apparaître [child] en fondu + léger glissement vers le haut,
  /// sur la tranche `[start, end]` (0..1) de l'animation d'entrée — un
  /// décalage différent par section donne l'effet d'apparition en cascade.
  Widget _reveal({
    required double start,
    required double end,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 18),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdge,
            AppSpacing.xl,
            AppSpacing.screenEdge,
            AppSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reveal(
                start: 0,
                end: 0.5,
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.or.withValues(
                            alpha: 0.4 + 0.6 * _pulse.value,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text('SAISON 2025–2026', style: AppText.eyebrow),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              _reveal(
                start: 0.05,
                end: 0.55,
                child: const Wordmark(fontSize: 52),
              ),
              const SizedBox(height: AppSpacing.m),
              _reveal(
                start: 0.1,
                end: 0.6,
                child: Text(
                  'Le classement compte tout seul. Pronostique, compare, '
                  'remporte la mise.',
                  style: AppText.body.copyWith(color: AppColors.ardoise),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final (i, (icon, label)) in _features.indexed)
                _reveal(
                  start: 0.15 + i * 0.08,
                  end: 0.65 + i * 0.08,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.m),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.tribune,
                            borderRadius: AppRadii.allS,
                            border: Border.all(color: AppColors.ligne),
                          ),
                          child: Icon(icon, size: 18, color: AppColors.or),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(label, style: AppText.body)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s),
              _reveal(
                start: 0.4,
                end: 0.85,
                child: const SectionLabel('Comment ça marche'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _reveal(start: 0.45, end: 0.9, child: const _HowItWorks()),
              const SizedBox(height: AppSpacing.l),
              _reveal(start: 0.5, end: 0.95, child: _PreviewCard()),
              const SizedBox(height: AppSpacing.l),
              _reveal(
                start: 0.55,
                end: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () => openAuth(context, register: true),
                      child: const Text('REJOINDRE GRATUITEMENT'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: () => openAuth(context, register: false),
                        child: const Text('Déjà inscrit ? Se connecter'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (final (i, (step, icon, label))
              in _LandingScreenState._steps.indexed) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(),
              ),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.or,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    step,
                    style: AppText.button.copyWith(
                      fontSize: 13,
                      color: AppColors.surOr,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: 18, color: AppColors.ardoise),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label, style: AppText.body)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Classement live · Les Potos'),
          const SizedBox(height: AppSpacing.sm),
          for (final (rank, icon, name, points) in _LandingScreenState._preview)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '$rank',
                      style: AppText.mono.copyWith(color: AppColors.or),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Icon(icon, size: 16, color: AppColors.ardoise),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      name,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '$points',
                    style: AppText.mono.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
