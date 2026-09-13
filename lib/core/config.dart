/// Configuration d'exécution.
///
/// Les secrets ne sont jamais versionnés : ils sont injectés au lancement via
/// `--dart-define-from-file=env.json` (ou `--dart-define` individuels).
library;

class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Vrai lorsque les deux secrets Supabase ont été fournis au build.
  ///
  /// Permet de faire échouer le démarrage avec un message clair plutôt que
  /// de laisser `supabase_flutter` lever une erreur obscure.
  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
