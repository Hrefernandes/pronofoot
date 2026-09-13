import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale française pour le regroupement des matchs par jour (E2).
  await initializeDateFormatting('fr_FR');

  if (!AppConfig.hasSupabaseCredentials) {
    // Démarrage explicitement en échec plutôt qu'une erreur obscure plus tard.
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: PronoFootApp()));
}

/// Écran affiché quand `SUPABASE_URL` / `SUPABASE_ANON_KEY` manquent au build.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration manquante.\n\n'
              'Lance avec : flutter run '
              '--dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
