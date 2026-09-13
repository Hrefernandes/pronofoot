import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pronofoot/core/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('DateFmt.dayHeader', () {
    final now = DateTime(2026, 3, 14, 12);

    test('même jour → Aujourd\'hui', () {
      expect(
        DateFmt.dayHeader(DateTime(2026, 3, 14, 21), now: now),
        "Aujourd'hui",
      );
    });

    test('lendemain → Demain', () {
      expect(DateFmt.dayHeader(DateTime(2026, 3, 15, 18), now: now), 'Demain');
    });

    test('plus loin → jour + quantième capitalisé', () {
      expect(
        DateFmt.dayHeader(DateTime(2026, 3, 21, 18), now: now),
        startsWith('Samedi'),
      );
    });
  });

  group('DateFmt.closesIn', () {
    final now = DateTime(2026, 3, 14, 12);

    test('plus d\'une heure → "Ferme dans N h"', () {
      expect(
        DateFmt.closesIn(DateTime(2026, 3, 14, 16), now: now),
        'Ferme dans 4 h',
      );
    });

    test('moins d\'une heure → minutes', () {
      expect(
        DateFmt.closesIn(DateTime(2026, 3, 14, 12, 25), now: now),
        'Ferme dans 25 min',
      );
    });

    test('coup d\'envoi passé → Fermé', () {
      expect(DateFmt.closesIn(DateTime(2026, 3, 14, 11), now: now), 'Fermé');
    });
  });
}
