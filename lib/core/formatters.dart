/// Helpers de formatage de dates et d'heures, localisés en français.
///
/// `initializeDateFormatting('fr_FR')` est appelé une fois au démarrage
/// (`main.dart`).
library;

import 'package:intl/intl.dart';

abstract final class DateFmt {
  static final DateFormat _hourMinute = DateFormat.Hm('fr_FR');
  static final DateFormat _weekdayDay = DateFormat('EEEE d', 'fr_FR');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'fr_FR');

  /// `21:00`
  static String hourMinute(DateTime dt) => _hourMinute.format(dt.toLocal());

  /// En-tête de groupe de matchs : `Aujourd'hui`, `Demain`, sinon `Samedi 15`.
  static String dayHeader(DateTime dt, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final day = _dateOnly(dt.toLocal());
    final diff = day.difference(today).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Demain';
    if (diff == -1) return 'Hier';
    final label = _weekdayDay.format(day);
    return label[0].toUpperCase() + label.substring(1);
  }

  /// Clé de regroupement stable (année-mois-jour en local).
  static DateTime dayKey(DateTime dt) => _dateOnly(dt.toLocal());

  /// `Membre depuis mars 2026`
  static String memberSince(DateTime dt) => _monthYear.format(dt.toLocal());

  /// Compte à rebours court avant le coup d'envoi : `Ferme dans 4 h`,
  /// `Ferme dans 25 min`, ou `Fermé` si le délai est écoulé.
  static String closesIn(DateTime kickoff, {DateTime? now}) {
    final remaining = kickoff.toLocal().difference(now ?? DateTime.now());
    if (remaining.isNegative) return 'Fermé';
    if (remaining.inHours >= 1) return 'Ferme dans ${remaining.inHours} h';
    final minutes = remaining.inMinutes.clamp(1, 59);
    return 'Ferme dans $minutes min';
  }

  static DateTime _dateOnly(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
