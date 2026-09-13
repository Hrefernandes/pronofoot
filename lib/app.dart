import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/landing_screen.dart';

/// Racine de l'application. Le thème sombre est unique (pas de bascule).
class PronoFootApp extends StatelessWidget {
  const PronoFootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PronoFoot',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Aiguille selon l'état de session :
/// chargement → splash, déconnecté → E0/E1, connecté → coquille à onglets.
///
/// Le splash reste affiché au moins [_minSplashDuration], même si la session
/// Supabase répond instantanément (locale, déjà en cache) — sans ce minimum
/// l'écran de chargement clignote à peine et paraît être un bug plutôt
/// qu'une transition voulue.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  static const _minSplashDuration = Duration(milliseconds: 2600);
  bool _minDurationElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _minDurationElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    if (!_minDurationElapsed) return const _Splash();
    return auth.when(
      loading: () => const _Splash(),
      error: (_, _) => const LandingScreen(),
      data: (profile) =>
          profile == null ? const LandingScreen() : const HomeShell(),
    );
  }
}

/// Écran de chargement : un ballon doré qui roule d'avant en arrière au-dessus
/// d'une ligne (le terrain, stylisé — le vert de la pelouse est réservé au
/// score exact ailleurs dans l'app, donc pas de vert ici).
class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const travel = 56.0;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: travel + 40,
              height: 56,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final dx = (t - 0.5) * travel;
                  final angle = t * 6.28318 * 2.4;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: travel + 40,
                          height: 2,
                          color: AppColors.ligne,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          child: Transform.rotate(
                            angle: angle,
                            child: const Icon(
                              Icons.sports_soccer,
                              color: AppColors.or,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Text('CHARGEMENT…', style: AppText.eyebrow),
          ],
        ),
      ),
    );
  }
}

/// Route utilitaire : pousse [AuthScreen] avec le mode voulu.
void openAuth(BuildContext context, {required bool register}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AuthScreen(startInRegister: register),
    ),
  );
}
