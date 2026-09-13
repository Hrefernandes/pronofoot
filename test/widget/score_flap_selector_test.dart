import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/widgets/score_flap_selector.dart';

void main() {
  Widget host({
    required int home,
    required int away,
    required void Function(int, int) onChanged,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ScoreFlapSelector(
          homeScore: home,
          awayScore: away,
          homeLabel: 'PSG',
          awayLabel: 'OM',
          onChanged: onChanged,
          lockLabel: 'Modifiable jusqu\'à 21:00',
          enabled: enabled,
        ),
      ),
    );
  }

  testWidgets('affiche les deux scores et la barre de verrouillage', (
    tester,
  ) async {
    await tester.pumpWidget(host(home: 2, away: 1, onChanged: (_, _) {}));

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Modifiable jusqu'), findsOneWidget);
  });

  testWidgets('le + de gauche incrémente le score domicile', (tester) async {
    int? h;
    int? a;
    await tester.pumpWidget(
      host(
        home: 0,
        away: 0,
        onChanged: (nh, na) {
          h = nh;
          a = na;
        },
      ),
    );

    await tester.tap(find.byIcon(Icons.add).first);
    expect(h, 1);
    expect(a, 0);
  });

  testWidgets('le score ne descend pas sous 0 (borne CHECK base)', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(home: 0, away: 0, onChanged: (_, _) => calls++),
    );

    // À 0, les boutons "−" sont désactivés.
    await tester.tap(find.byIcon(Icons.remove).first);
    expect(calls, 0);
  });

  testWidgets('désactivé : les boutons ne rappellent plus onChanged', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(home: 1, away: 1, enabled: false, onChanged: (_, _) => calls++),
    );

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.remove).first);
    expect(calls, 0);
  });
}
