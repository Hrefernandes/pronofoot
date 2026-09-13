import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'badges.dart';
import 'common.dart';
import 'team_monogram.dart';

/// Carte d'un match dans la liste E2.
///
/// Le pied de carte reflète l'état du pronostic de l'utilisateur dans le
/// groupe actif : à pronostiquer, enregistré, score exact, ou aucun contexte
/// de groupe.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.view, this.prediction, this.onTap});

  final MatchView view;
  final Prediction? prediction;
  final VoidCallback? onTap;

  bool get _isExact =>
      view.status.isFinished &&
      prediction != null &&
      prediction!.homeScorePred == view.match.homeScore &&
      prediction!.awayScorePred == view.match.awayScore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.sm),
          _teamRow(view.homeTeam, view.match.homeScore),
          const SizedBox(height: AppSpacing.s),
          _teamRow(view.awayTeam, view.match.awayScore),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Text(
            view.league.name.toUpperCase(),
            style: AppText.eyebrow,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (view.status.isLive)
          const StatusBadge.live()
        else
          Text(DateFmt.hourMinute(view.kickoffAt), style: AppText.mono),
      ],
    );
  }

  Widget _teamRow(Team team, int? score) {
    final showScore = view.status.isLive || view.status.isFinished;
    return Row(
      children: [
        TeamMonogram(team: team),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            team.name,
            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showScore)
          Text(
            '${score ?? 0}',
            style: AppText.mono.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _footer() {
    if (_isExact) return const StatusBadge.exact();

    if (prediction != null) {
      final statusText = switch (view.status) {
        MatchStatus.finished => 'Terminé',
        MatchStatus.live => 'En cours',
        MatchStatus.scheduled => 'Enregistré',
      };
      return Row(
        children: [
          Text('Ton prono ', style: AppText.bodyMuted),
          Text(
            '${prediction!.homeScorePred} – ${prediction!.awayScorePred}',
            style: AppText.mono.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(statusText, style: AppText.bodyMuted),
        ],
      );
    }

    if (view.match.isOpenForPrediction()) {
      return Row(
        children: [
          const StatusBadge.toPredict(),
          const Spacer(),
          Text(DateFmt.closesIn(view.kickoffAt), style: AppText.bodyMuted),
        ],
      );
    }

    return Text('Pronostic fermé', style: AppText.bodyMuted);
  }
}
