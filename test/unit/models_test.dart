import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/models/models.dart';

void main() {
  group('MatchView.fromJson', () {
    test('assemble le match, les deux équipes et la compétition', () {
      final json = {
        'id': 'm1',
        'league_id': 'l1',
        'home_team_id': 't1',
        'away_team_id': 't2',
        'kickoff_at': '2026-03-14T20:00:00Z',
        'home_score': null,
        'away_score': null,
        'status': 'scheduled',
        'home_team': {
          'id': 't1',
          'league_id': 'l1',
          'short_name': 'PSG',
          'name': 'Paris Saint-Germain',
          'color_primary': '#0B1220',
          'color_secondary': '#FFFFFF',
          'color_text': '#FFFFFF',
        },
        'away_team': {
          'id': 't2',
          'league_id': 'l1',
          'short_name': 'OM',
          'name': 'Olympique de Marseille',
          'color_primary': '#FFFFFF',
          'color_secondary': '#0B1220',
          'color_text': '#0B1220',
        },
        'league': {
          'id': 'l1',
          'name': 'Ligue 1',
          'country': 'France',
          'color_primary': '#16203A',
          'color_secondary': '#1E2A47',
          'color_text': '#F2F5FF',
        },
      };

      final view = MatchView.fromJson(json);

      expect(view.id, 'm1');
      expect(view.homeTeam.shortName, 'PSG');
      expect(view.awayTeam.name, 'Olympique de Marseille');
      expect(view.league.name, 'Ligue 1');
      expect(view.status, MatchStatus.scheduled);
    });
  });

  group('Match.isOpenForPrediction (RG-01, confort UI)', () {
    Match make(MatchStatus status, DateTime kickoff) => Match(
      id: 'm',
      leagueId: 'l',
      homeTeamId: 'h',
      awayTeamId: 'a',
      kickoffAt: kickoff,
      status: status,
    );

    final now = DateTime.utc(2026, 3, 14, 12);

    test('programmé et coup d\'envoi à venir → ouvert', () {
      final m = make(MatchStatus.scheduled, DateTime.utc(2026, 3, 14, 20));
      expect(m.isOpenForPrediction(now: now), isTrue);
    });

    test('coup d\'envoi passé → fermé', () {
      final m = make(MatchStatus.scheduled, DateTime.utc(2026, 3, 14, 10));
      expect(m.isOpenForPrediction(now: now), isFalse);
    });

    test('match live → fermé même si l\'heure semble future', () {
      final m = make(MatchStatus.live, DateTime.utc(2026, 3, 14, 20));
      expect(m.isOpenForPrediction(now: now), isFalse);
    });
  });

  group('Prediction', () {
    test(
      'points_earned null = non calculé ; 0 = calculé sans point (RG-05)',
      () {
        final base = {
          'id': 'p1',
          'group_id': 'g1',
          'profile_id': 'u1',
          'match_id': 'm1',
          'home_score_pred': 1,
          'away_score_pred': 1,
          'created_at': '2026-03-14T10:00:00Z',
        };
        expect(Prediction.fromJson({...base}).isScored, isFalse);
        expect(
          Prediction.fromJson({...base, 'points_earned': 0}).isScored,
          isTrue,
        );
      },
    );
  });

  group('MyStats', () {
    test('success_rate est arrondi à l\'entier', () {
      final stats = MyStats.fromJson({
        'total_predictions': 31,
        'exact_scores': 6,
        'correct_outcomes': 14,
        'total_points': 52,
        'success_rate': 64.4,
      });
      expect(stats.successRate, 64);
      expect(stats.totalPoints, 52);
    });

    test('JSON vide → MyStats.empty équivalent', () {
      final stats = MyStats.fromJson(const {});
      expect(stats.totalPredictions, 0);
      expect(stats.successRate, 0);
    });
  });

  group('Group', () {
    test('scoringLabel formate le barème', () {
      final group = Group.fromJson({
        'id': 'g1',
        'name': 'Les Potos',
        'invite_code': 'K7XM2P',
        'points_exact': 3,
        'points_result': 1,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(group.scoringLabel, '3 pts / 1 pt');
    });
  });
}
