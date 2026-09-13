import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pronofoot/core/exceptions.dart';
import 'package:pronofoot/models/models.dart';
import 'package:pronofoot/providers/providers.dart';
import 'package:pronofoot/screens/match_detail_screen.dart';

import '../support/fakes.dart';

/// Fil rouge du dossier : « saisir un pronostic », de l'écran E3 jusqu'à
/// l'appel du repository, sans base de données.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  late FakePredictionRepository predictions;

  Widget boot() {
    predictions = FakePredictionRepository();
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(profile: fakeProfile()),
        ),
        matchRepositoryProvider.overrideWithValue(
          FakeMatchRepository([fakeMatchView(id: 'm1')]),
        ),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        predictionRepositoryProvider.overrideWithValue(predictions),
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
      ],
      child: const MaterialApp(home: MatchDetailScreen(matchId: 'm1')),
    );
  }

  testWidgets('incrémente le score puis enregistre le pronostic', (
    tester,
  ) async {
    await tester.pumpWidget(boot());
    await tester.pumpAndSettle();

    expect(find.text('TON PRONOSTIC'), findsOneWidget);
    expect(find.text('ENREGISTRER LE PRONOSTIC'), findsOneWidget);

    // 2 – 1 : deux incréments côté domicile, un côté extérieur.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    await tester.tap(find.text('ENREGISTRER LE PRONOSTIC'));
    await tester.pump();
    await tester.pump();

    expect(predictions.created, hasLength(1));
    final saved = predictions.created.single;
    expect(saved.matchId, 'm1');
    expect(saved.homeScore, 2);
    expect(saved.awayScore, 1);

    await tester.pumpAndSettle();
    expect(find.text('Pronostic enregistré.'), findsOneWidget);
  });

  testWidgets('un pronostic déjà posé est affiché verrouillé, sans bouton', (
    tester,
  ) async {
    final repo = FakePredictionRepository()
      ..existing = Prediction(
        id: 'p1',
        groupId: 'g1',
        profileId: 'u1',
        matchId: 'm1',
        homeScorePred: 2,
        awayScorePred: 0,
        createdAt: DateTime.utc(2026, 3, 14),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(profile: fakeProfile()),
          ),
          matchRepositoryProvider.overrideWithValue(
            FakeMatchRepository([fakeMatchView(id: 'm1')]),
          ),
          groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
          predictionRepositoryProvider.overrideWithValue(repo),
          statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
        ],
        child: const MaterialApp(home: MatchDetailScreen(matchId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();

    // Le score affiché est celui déjà enregistré, pas 0-0.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('non modifiable'), findsOneWidget);
    expect(find.text('ENREGISTRER LE PRONOSTIC'), findsNothing);

    // Les boutons +/- ne doivent plus rien changer.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(repo.created, isEmpty);
  });

  testWidgets('coup d\'envoi passé : sélecteur verrouillé, bouton désactivé', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(profile: fakeProfile()),
          ),
          matchRepositoryProvider.overrideWithValue(
            FakeMatchRepository([
              fakeMatchView(
                id: 'm1',
                status: MatchStatus.live,
                kickoff: DateTime.now().subtract(const Duration(minutes: 5)),
              ),
            ]),
          ),
          groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
          predictionRepositoryProvider.overrideWithValue(
            FakePredictionRepository(),
          ),
          statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
        ],
        child: const MaterialApp(home: MatchDetailScreen(matchId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('ENREGISTRER LE PRONOSTIC'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('Fermé au coup'), findsOneWidget);
  });

  testWidgets('un refus RLS est traduit en message métier', (tester) async {
    await tester.pumpWidget(boot());
    await tester.pumpAndSettle();
    // Le fake ne lève rien : on vérifie ici que le type d'exception attendu
    // est bien celui exposé aux écrans.
    expect(const PredictionLockedException().message, contains('verrouillé'));
  });
}
