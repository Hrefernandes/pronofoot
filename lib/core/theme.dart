/// Jetons de design et thème Material.
///
/// Direction « Tableau d'affichage » : le panneau de scores d'un stade au
/// crépuscule. Aucune couleur n'est codée en dur ailleurs dans l'application ;
/// tout passe par [AppColors], [AppSpacing], [AppRadii] et [AppText].
library;

import 'package:flutter/material.dart';

/// Palette — vérifiée en contraste WCAG AA.
abstract final class AppColors {
  /// Fond de l'application.
  static const Color nuit = Color(0xFF0B1220);

  /// Cartes, champs, surfaces élevées.
  static const Color tribune = Color(0xFF16203A);

  /// Surface au-dessus d'une carte.
  static const Color tribune2 = Color(0xFF1E2A47);

  /// Texte principal.
  static const Color craie = Color(0xFFF2F5FF);

  /// Texte secondaire, icônes inactives.
  static const Color ardoise = Color(0xFF7C89A8);

  /// Accent unique : points, boutons, état actif, direct.
  static const Color or = Color(0xFFFFB020);

  /// RÉSERVÉ au score exact. Aucun autre usage.
  static const Color exact = Color(0xFF5CE28A);

  /// Erreurs, déconnexion.
  static const Color alerte = Color(0xFFFF6B6B);

  /// Bordures : blanc craie à 10 %.
  static const Color ligne = Color(0x1AF2F5FF);

  /// Texte posé sur un fond [or] (boutons primaires).
  static const Color surOr = nuit;
}

/// Échelle d'espacement : 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double sm = 12;
  static const double m = 16;
  static const double ml = 20;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 40;

  /// Marge latérale d'écran.
  static const double screenEdge = 18;
}

/// Rayons de coin : s 10 · m 14 · l 20 · xl 28.
abstract final class AppRadii {
  static const Radius s = Radius.circular(10);
  static const Radius m = Radius.circular(14);
  static const Radius l = Radius.circular(20);
  static const Radius xl = Radius.circular(28);

  /// Rayon du monogramme d'équipe.
  static const Radius monogram = Radius.circular(9);

  static const BorderRadius allS = BorderRadius.all(s);
  static const BorderRadius allM = BorderRadius.all(m);
  static const BorderRadius allL = BorderRadius.all(l);
  static const BorderRadius allXl = BorderRadius.all(xl);
}

/// Hauteurs de bouton.
abstract final class AppButtonSize {
  static const double small = 40;
  static const double medium = 46;
  static const double large = 50;
}

/// Familles de polices — voir `pubspec.yaml`.
abstract final class AppFonts {
  /// Titres, wordmark. Toujours en capitales.
  static const String display = 'Archivo';

  /// Texte courant.
  static const String body = 'Instrument Sans';

  /// Scores, codes, heures, eyebrows. Chasse fixe : aligne les colonnes.
  static const String mono = 'Azeret Mono';
}

/// Styles typographiques nommés, indépendants du `TextTheme` Material.
///
/// Les écrans utilisent ces constantes plutôt que `Theme.of(context)` pour
/// les cas spécifiques (eyebrow mono, gros score, wordmark).
abstract final class AppText {
  /// Titre d'écran — capitales, Archivo 800.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.5,
    color: AppColors.craie,
  );

  /// Titre de section dans une carte.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.craie,
  );

  /// Surtitre mono en capitales espacées (« LIGUE 1 · JOURNÉE 4 »).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.ardoise,
  );

  /// Corps de texte standard.
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.craie,
  );

  /// Corps secondaire.
  static const TextStyle bodyMuted = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.ardoise,
  );

  /// Libellé de bouton — capitales.
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  /// Nombre mis en avant (points, statistiques).
  static const TextStyle statNumber = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.craie,
  );

  /// Score géant du sélecteur en volets (écran E3).
  ///
  /// `height: 1` resserre la boîte de ligne sur les chiffres : sans ça, la
  /// métrique de la police laisse de l'espace sous le glyphe (pas de
  /// jambage sur un chiffre) et le score paraît décalé vers le haut du
  /// volet au lieu d'être centré sur le filet.
  static const TextStyle flapScore = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 52,
    fontWeight: FontWeight.w800,
    height: 1,
    color: AppColors.craie,
  );

  /// Heure de coup d'envoi, code d'invitation.
  static const TextStyle mono = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.craie,
  );
}

/// Fabrique du [ThemeData] unique de l'application (thème sombre fixe).
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.or,
    onPrimary: AppColors.surOr,
    secondary: AppColors.or,
    onSecondary: AppColors.surOr,
    surface: AppColors.tribune,
    onSurface: AppColors.craie,
    error: AppColors.alerte,
    onError: AppColors.craie,
    outline: AppColors.ligne,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.nuit,
    fontFamily: AppFonts.body,
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.craie,
      displayColor: AppColors.craie,
      fontFamily: AppFonts.body,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.nuit,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.craie),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.tribune,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.allL),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.ligne,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.tribune,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.m,
      ),
      hintStyle: const TextStyle(color: AppColors.ardoise),
      labelStyle: const TextStyle(color: AppColors.ardoise),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadii.allM,
        borderSide: BorderSide(color: AppColors.ligne),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadii.allM,
        borderSide: BorderSide(color: AppColors.or, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadii.allM,
        borderSide: BorderSide(color: AppColors.alerte),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadii.allM,
        borderSide: BorderSide(color: AppColors.alerte, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.or,
        foregroundColor: AppColors.surOr,
        disabledBackgroundColor: AppColors.tribune2,
        disabledForegroundColor: AppColors.ardoise,
        minimumSize: const Size.fromHeight(AppButtonSize.large),
        elevation: 0,
        textStyle: AppText.button,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.allM),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.or,
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.craie,
        minimumSize: const Size.fromHeight(AppButtonSize.large),
        side: const BorderSide(color: AppColors.ligne),
        textStyle: AppText.button,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.allM),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.tribune2,
      contentTextStyle: TextStyle(color: AppColors.craie),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.nuit,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.or : AppColors.ardoise,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.or : AppColors.ardoise,
        );
      }),
    ),
  );
}
