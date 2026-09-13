import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/score_flap_selector.dart';
import '../widgets/team_monogram.dart';

/// E3 — Détail d'un match, saisie du pronostic (fil rouge du dossier) et
/// pronostics des groupes.
///
/// Un pronostic se saisit une seule fois pour un match et vaut pour tous les
/// groupes de l'utilisateur : une seule action, répliquée en base sur
/// chaque groupe (le barème diffère par groupe, pas le score prédit). Une
/// fois enregistré, il n'est plus modifiable ni supprimable.
class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  int _home = 0;
  int _away = 0;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(predictionRepositoryProvider)
          .createPrediction(
            matchId: widget.matchId,
            homeScore: _home,
            awayScore: _away,
          );
      if (!mounted) return;
      ref.invalidate(myPredictionProvider(widget.matchId));
      ref.invalidate(myPredictionsProvider);
      // Ces deux-là ne sont lus qu'à l'ouverture de l'écran E6 : sans cette
      // invalidation, ils restent en cache et ignorent le nouveau pronostic.
      ref.invalidate(myRecentPredictionsProvider);
      ref.invalidate(myStatsProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pronostic enregistré.')));
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchViewProvider(widget.matchId));
    final groups = ref.watch(myGroupsProvider).valueOrNull ?? const [];
    final predictionAsync = ref.watch(myPredictionProvider(widget.matchId));
    final existing = predictionAsync.valueOrNull;

    // Un pronostic existant est immuable : on resynchronise les volets sur
    // sa valeur à chaque build plutôt que de ne le faire qu'une fois — sans
    // ça, une frappe faite pendant le chargement (avant de savoir qu'un
    // pronostic existe déjà) resterait affichée à tort après coup.
    if (existing != null) {
      _home = existing.homeScorePred;
      _away = existing.awayScorePred;
    }

    return Scaffold(
      appBar: AppBar(title: Text('PRONOSTIC', style: AppText.eyebrow)),
      body: AsyncView(
        value: matchAsync,
        onRetry: () => ref.invalidate(matchViewProvider(widget.matchId)),
        data: (match) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenEdge,
              AppSpacing.s,
              AppSpacing.screenEdge,
              AppSpacing.xxl,
            ),
            children: [
              _MatchHeader(match: match),
              const SizedBox(height: AppSpacing.l),
              if (groups.isEmpty)
                const _JoinGroupToPredict()
              else
                _PredictionBlock(
                  match: match,
                  home: _home,
                  away: _away,
                  saving: _saving,
                  alreadyPredicted: existing != null,
                  onChanged: (h, a) => setState(() {
                    _home = h;
                    _away = a;
                  }),
                  onSave: _save,
                ),
              const SizedBox(height: AppSpacing.xl),
              for (final membership in groups) ...[
                _GroupPredictions(
                  groupId: membership.groupId,
                  groupName: membership.group.name,
                  matchId: widget.matchId,
                  kickoffPassed: !match.match.isOpenForPrediction(),
                ),
                const SizedBox(height: AppSpacing.l),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});

  final MatchView match;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  TeamMonogram.large(team: match.homeTeam),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    match.homeTeam.name,
                    textAlign: TextAlign.center,
                    style: AppText.bodyMuted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text('—', style: AppText.bodyMuted),
            ),
            Expanded(
              child: Column(
                children: [
                  TeamMonogram.large(team: match.awayTeam),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    match.awayTeam.name,
                    textAlign: TextAlign.center,
                    style: AppText.bodyMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          '${DateFmt.dayHeader(match.kickoffAt)} · '
          '${DateFmt.hourMinute(match.kickoffAt)} · ${match.league.name}',
          textAlign: TextAlign.center,
          style: AppText.eyebrow,
        ),
      ],
    );
  }
}

class _PredictionBlock extends StatelessWidget {
  const _PredictionBlock({
    required this.match,
    required this.home,
    required this.away,
    required this.saving,
    required this.alreadyPredicted,
    required this.onChanged,
    required this.onSave,
  });

  final MatchView match;
  final int home;
  final int away;
  final bool saving;
  final bool alreadyPredicted;
  final void Function(int home, int away) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final open = match.match.isOpenForPrediction();
    // Verrouillé dès l'enregistrement, pas seulement au coup d'envoi : un
    // pronostic posé n'est plus jamais modifiable.
    final editable = open && !alreadyPredicted;
    final lockLabel = alreadyPredicted
        ? 'Pronostic verrouillé'
        : open
        ? 'À valider avant ${DateFmt.hourMinute(match.kickoffAt)}'
        : 'Fermé au coup d\'envoi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Ton pronostic'),
        const SizedBox(height: AppSpacing.m),
        ScoreFlapSelector(
          homeScore: home,
          awayScore: away,
          homeLabel: match.homeTeam.shortName,
          awayLabel: match.awayTeam.shortName,
          onChanged: onChanged,
          lockLabel: lockLabel,
          enabled: editable && !saving,
        ),
        const SizedBox(height: AppSpacing.m),
        if (alreadyPredicted)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 14, color: AppColors.ardoise),
                const SizedBox(width: AppSpacing.s),
                Text(
                  'Pronostic enregistré — non modifiable',
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          )
        else
          ElevatedButton(
            onPressed: editable && !saving ? onSave : null,
            child: saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surOr,
                    ),
                  )
                : const Text('ENREGISTRER LE PRONOSTIC'),
          ),
      ],
    );
  }
}

class _JoinGroupToPredict extends StatelessWidget {
  const _JoinGroupToPredict();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text('Aucun groupe', style: AppText.cardTitle),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Rejoins ou crée un groupe depuis l\'onglet Groupes pour '
            'pronostiquer ce match.',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _GroupPredictions extends StatelessWidget {
  const _GroupPredictions({
    required this.groupId,
    required this.groupName,
    required this.matchId,
    required this.kickoffPassed,
  });

  final String groupId;
  final String groupName;
  final String matchId;
  final bool kickoffPassed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(groupName),
        const SizedBox(height: AppSpacing.sm),
        if (!kickoffPassed)
          AppCard(
            child: Column(
              children: [
                Text('Pronostics masqués', style: AppText.cardTitle),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Les pronos des autres membres apparaîtront au coup '
                  'd\'envoi (RG-08).',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(
                groupPredictionsProvider((groupId: groupId, matchId: matchId)),
              );
              return AsyncView(
                value: async,
                onRetry: () => ref.invalidate(
                  groupPredictionsProvider((
                    groupId: groupId,
                    matchId: matchId,
                  )),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return AppCard(
                      child: Text(
                        'Aucun autre pronostic sur ce match.',
                        style: AppText.bodyMuted,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s),
                          child: _GroupPredictionRow(row: row),
                        ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _GroupPredictionRow extends StatelessWidget {
  const _GroupPredictionRow({required this.row});

  final GroupPrediction row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          ProfileAvatar(icon: row.avatarIcon, color: row.avatarColor, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              row.username,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${row.homeScorePred} – ${row.awayScorePred}',
            style: AppText.mono.copyWith(fontWeight: FontWeight.w700),
          ),
          if (row.pointsEarned != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '+${row.pointsEarned}',
              style: AppText.mono.copyWith(
                color: row.pointsEarned! > 0 ? AppColors.or : AppColors.ardoise,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
