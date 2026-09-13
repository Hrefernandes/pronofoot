import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';

/// Filtre par état du pronostic / du match, en plus du filtre par
/// compétition (E2) — utile dès que le jeu de données dépasse une poignée
/// de matchs.
enum _StatusFilter { all, toPredict, live, finished }

extension on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'Tous',
    _StatusFilter.toPredict => 'À pronostiquer',
    _StatusFilter.live => 'En direct',
    _StatusFilter.finished => 'Terminés',
  };

  bool matches(MatchView view, bool alreadyPredicted) => switch (this) {
    _StatusFilter.all => true,
    _StatusFilter.toPredict =>
      view.match.isOpenForPrediction() && !alreadyPredicted,
    _StatusFilter.live => view.status.isLive,
    _StatusFilter.finished => view.status.isFinished,
  };
}

/// E2 — Liste des matchs à venir, groupés par jour, filtrable par état et
/// par compétition.
class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  _StatusFilter _statusFilter = _StatusFilter.all;

  /// `null` = toutes compétitions.
  String? _leagueFilter;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(upcomingMatchesProvider);
    final noGroup =
        (ref.watch(myGroupsProvider).valueOrNull ?? const []).isEmpty;
    final predictionsAsync = ref.watch(myPredictionsProvider);
    final predictions = predictionsAsync.valueOrNull ?? const {};

    return RefreshIndicator(
      color: AppColors.or,
      onRefresh: () async {
        ref.invalidate(upcomingMatchesProvider);
        ref.invalidate(myPredictionsProvider);
        await ref.read(upcomingMatchesProvider.future);
      },
      child: AsyncView(
        value: matchesAsync,
        onRetry: () => ref.invalidate(upcomingMatchesProvider),
        data: (matches) {
          final openWithoutPrediction = matches
              .where(
                (m) =>
                    m.match.isOpenForPrediction() &&
                    !predictions.containsKey(m.id),
              )
              .length;

          final leagues = _leaguesIn(matches);
          // Si la compétition sélectionnée a disparu du jeu de données
          // (rechargement), on revient silencieusement sur « Toutes ».
          if (_leagueFilter != null &&
              !leagues.any((l) => l.id == _leagueFilter)) {
            _leagueFilter = null;
          }

          final filtered = matches.where((m) {
            if (_leagueFilter != null && m.league.id != _leagueFilter) {
              return false;
            }
            return _statusFilter.matches(m, predictions.containsKey(m.id));
          }).toList();

          final groups = _groupByDay(filtered);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenEdge,
              AppSpacing.m,
              AppSpacing.screenEdge,
              AppSpacing.xxl,
            ),
            children: [
              ScreenTitle(
                'Matchs',
                subtitle: openWithoutPrediction == 0
                    ? 'Tous tes pronostics sont posés'
                    : '$openWithoutPrediction match'
                          '${openWithoutPrediction > 1 ? 's' : ''} sans pronostic',
              ),
              if (noGroup) ...[
                const SizedBox(height: AppSpacing.m),
                const _NoGroupHint(),
              ],
              const SizedBox(height: AppSpacing.l),
              _FilterRow(
                children: [
                  for (final f in _StatusFilter.values)
                    _FilterChip(
                      label: f.label,
                      selected: _statusFilter == f,
                      onTap: () => setState(() => _statusFilter = f),
                    ),
                ],
              ),
              if (leagues.length > 1) ...[
                const SizedBox(height: AppSpacing.s),
                _FilterRow(
                  children: [
                    _FilterChip(
                      label: 'Toutes compétitions',
                      selected: _leagueFilter == null,
                      onTap: () => setState(() => _leagueFilter = null),
                    ),
                    for (final league in leagues)
                      _FilterChip(
                        label: league.name,
                        selected: _leagueFilter == league.id,
                        onTap: () => setState(() => _leagueFilter = league.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.l),
              for (final entry in groups) ...[
                SectionLabel(DateFmt.dayHeader(entry.key)),
                const SizedBox(height: AppSpacing.sm),
                for (final match in entry.value) ...[
                  MatchCard(
                    view: match,
                    prediction: predictions[match.id],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MatchDetailScreen(matchId: match.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.s),
              ],
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'Aucun match à venir pour le moment.',
                      style: AppText.bodyMuted,
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'Aucun match ne correspond à ces filtres.',
                      style: AppText.bodyMuted,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Compétitions présentes dans la liste, triées par nom — pas de liste
  /// figée en dur : un nouveau championnat dans le jeu de données apparaît
  /// automatiquement.
  List<League> _leaguesIn(List<MatchView> matches) {
    final byId = <String, League>{};
    for (final match in matches) {
      byId[match.league.id] = match.league;
    }
    final leagues = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return leagues;
  }

  /// Regroupe les matchs par jour local, en conservant l'ordre chronologique.
  List<MapEntry<DateTime, List<MatchView>>> _groupByDay(
    List<MatchView> matches,
  ) {
    final map = <DateTime, List<MatchView>>{};
    for (final match in matches) {
      final key = DateFmt.dayKey(match.kickoffAt);
      map.putIfAbsent(key, () => []).add(match);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }
}

/// Ligne de puces filtrantes, défilable horizontalement.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, i) => children[i],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.or : AppColors.tribune,
      borderRadius: AppRadii.allXl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.allXl,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.allXl,
            border: Border.all(
              color: selected ? AppColors.or : AppColors.ligne,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.surOr : AppColors.craie,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGroupHint extends StatelessWidget {
  const _NoGroupHint();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.ardoise, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Rejoins un groupe pour enregistrer tes pronostics.',
              style: AppText.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
