import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/sticker_picker.dart';

/// E6 — Profil, statistiques, déconnexion.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Le profil affiché vient normalement de authStateProvider (mis à jour à
  // la connexion/déconnexion). Après une modification de pseudo ou d'avatar,
  // on l'écrase localement avec la valeur renvoyée par le repository plutôt
  // que d'invalider authStateProvider : ce provider est surveillé tout en
  // haut de l'app (_AuthGate) pour décider si l'utilisateur est connecté —
  // l'invalider fait passer toute l'app par un écran de chargement et la
  // reconstruit entièrement, ce qui plantait l'arbre de widgets pendant
  // qu'une boîte de dialogue se fermait encore.
  Profile? _profileOverride;
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    // Cet écran reste vivant en arrière-plan (IndexedStack) même après une
    // déconnexion : sans ça, _profileOverride garderait l'avatar/pseudo du
    // compte précédent affiché par-dessus celui du nouveau compte connecté.
    final userId = ref.watch(currentUserIdProvider);
    if (userId != _lastUserId) {
      _lastUserId = userId;
      _profileOverride = null;
    }
    final profile = _profileOverride ?? ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(myStatsProvider);

    return RefreshIndicator(
      color: AppColors.or,
      onRefresh: () async {
        ref.invalidate(myStatsProvider);
        await ref.read(myStatsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenEdge,
          AppSpacing.m,
          AppSpacing.screenEdge,
          AppSpacing.xxl,
        ),
        children: [
          Text('PROFIL', style: AppText.screenTitle),
          const SizedBox(height: AppSpacing.l),
          if (profile != null)
            Row(
              children: [
                ProfileAvatar(
                  icon: profile.avatarIcon,
                  color: profile.avatarColor,
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: AppText.cardTitle.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Membre depuis ${DateFmt.memberSince(profile.createdAt)}',
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Mes statistiques'),
          const SizedBox(height: AppSpacing.sm),
          AsyncView(
            value: statsAsync,
            onRetry: () => ref.invalidate(myStatsProvider),
            data: (stats) => _StatsGrid(stats: stats),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Compte'),
          const SizedBox(height: AppSpacing.s),
          _AccountRow(
            label: 'Modifier mon avatar',
            onTap: () => _editAvatar(profile),
          ),
          const Divider(),
          _AccountRow(
            label: 'Modifier mon pseudo',
            onTap: () => _editUsername(profile?.username ?? ''),
          ),
          const Divider(),
          _AccountRow(
            label: 'Déconnexion',
            danger: true,
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _editUsername(String current) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _EditUsernameDialog(current: current),
    );
    if (newName == null || newName == current) return;

    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateUsername(newName);
      if (!mounted) return;
      setState(() => _profileOverride = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pseudo mis à jour.')));
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
  }

  Future<void> _editAvatar(Profile? profile) async {
    var icon = profile?.avatarIcon ?? 'ball';
    var color = profile?.avatarColor ?? '#FFB020';
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.nuit,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.xl),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> save() async {
              setSheetState(() => busy = true);
              try {
                final updated = await ref
                    .read(authRepositoryProvider)
                    .updateAvatar(avatarIcon: icon, avatarColor: color);
                if (mounted) setState(() => _profileOverride = updated);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avatar mis à jour.')),
                  );
                }
              } on AppException catch (error) {
                if (sheetContext.mounted) showErrorSnack(sheetContext, error);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => busy = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.screenEdge,
                right: AppSpacing.screenEdge,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.l,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'MODIFIER MON AVATAR',
                            style: AppText.cardTitle,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                          color: AppColors.ardoise,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    StickerPicker(
                      icon: icon,
                      color: color,
                      onIconChanged: (v) => setSheetState(() => icon = v),
                      onColorChanged: (v) => setSheetState(() => color = v),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    ElevatedButton(
                      onPressed: busy ? null : save,
                      child: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surOr,
                              ),
                            )
                          : const Text('ENREGISTRER'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Boîte de dialogue « Modifier mon pseudo ». Propre `StatefulWidget` plutôt
/// qu'un contrôleur créé/disposé à la main autour de `showDialog` : Flutter
/// a besoin d'appeler `dispose()` au bon moment du cycle de vie de
/// l'élément — le faire manuellement juste après la fermeture du dialogue
/// arrive trop tôt (l'animation de sortie n'est pas terminée) et fait
/// planter le prochain rebuild du `TextFormField`.
class _EditUsernameDialog extends StatefulWidget {
  const _EditUsernameDialog({required this.current});

  final String current;

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late final _controller = TextEditingController(text: widget.current);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.tribune,
      title: const Text('Modifier mon pseudo'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nouveau pseudo'),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.length < 3) return 'Au moins 3 caractères.';
            if (t.length > 20) return '20 caractères maximum.';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final MyStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '${stats.totalPoints}',
                label: 'Points au total',
                accent: AppColors.or,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                value: '${stats.totalPredictions}',
                label: 'Pronostics',
                onTap: () => showRecentPredictionsSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '${stats.exactScores}',
                label: 'Scores exacts',
                accent: AppColors.exact,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                value: '${stats.correctOutcomes}',
                label: 'Bons résultats',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _StatTile(
          value: '${stats.successRate}%',
          label: 'Taux de réussite',
          wide: true,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.accent,
    this.wide = false,
    this.onTap,
  });

  final String value;
  final String label;
  final Color? accent;
  final bool wide;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppText.statNumber.copyWith(
              color: accent ?? AppColors.craie,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label.toUpperCase(), style: AppText.eyebrow),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.alerte : AppColors.craie;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Feuille modale listant les derniers pronostics de l'utilisateur (E6) —
/// ouverte en tapant sur la tuile « Pronostics » des statistiques.
Future<void> showRecentPredictionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.nuit,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadii.xl),
    ),
    builder: (sheetContext) {
      final maxHeight = MediaQuery.of(sheetContext).size.height * 0.75;
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenEdge,
          right: AppSpacing.screenEdge,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.l,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MES DERNIERS PRONOSTICS',
                      style: AppText.cardTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.ardoise,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final async = ref.watch(myRecentPredictionsProvider);
                    return AsyncView(
                      value: async,
                      onRetry: () =>
                          ref.invalidate(myRecentPredictionsProvider),
                      data: (entries) {
                        if (entries.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.l,
                            ),
                            child: Text(
                              'Aucun pronostic pour l\'instant.',
                              style: AppText.bodyMuted,
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.s),
                          itemBuilder: (context, i) =>
                              _RecentPredictionRow(entry: entries[i]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RecentPredictionRow extends StatelessWidget {
  const _RecentPredictionRow({required this.entry});

  final RecentPrediction entry;

  @override
  Widget build(BuildContext context) {
    final decided = entry.pointsEarned != null;
    final exact =
        decided &&
        entry.predHome == entry.actualHomeScore &&
        entry.predAway == entry.actualAwayScore;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.homeTeamShort} – ${entry.awayTeamShort}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFmt.dayHeader(entry.kickoffAt)} · '
                  '${DateFmt.hourMinute(entry.kickoffAt)}',
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.predHome} – ${entry.predAway}',
                style: AppText.mono.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              if (decided)
                Text(
                  '+${entry.pointsEarned} pt${entry.pointsEarned! > 1 ? 's' : ''}',
                  style: AppText.mono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: exact
                        ? AppColors.exact
                        : entry.pointsEarned! > 0
                        ? AppColors.or
                        : AppColors.ardoise,
                  ),
                )
              else
                Text(
                  'En attente',
                  style: AppText.bodyMuted.copyWith(fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
