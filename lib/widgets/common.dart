import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions.dart';
import '../core/theme.dart';

/// Surtitre mono en capitales espacées (« MES STATISTIQUES »).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: AppText.eyebrow)),
        ?trailing,
      ],
    );
  }
}

/// Titre d'écran (Archivo 800, capitales).
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.toUpperCase(), style: AppText.screenTitle),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.s),
          Text(subtitle!, style: AppText.bodyMuted),
        ],
      ],
    );
  }
}

/// Carte standard : fond `tribune`, coins arrondis, padding cohérent.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.m),
    this.onTap,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Met la carte en avant (ligne du classement « toi »).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.tribune2 : AppColors.tribune,
      borderRadius: AppRadii.allL,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadii.allL,
            border: Border.all(
              color: highlight ? AppColors.or : AppColors.ligne,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Rend un [AsyncValue] avec des états de chargement / erreur homogènes.
///
/// L'erreur affichée est le message d'une [AppException] ; un bouton
/// « Réessayer » invalide le provider fourni.
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      data: data,
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator(color: AppColors.or)),
      ),
      error: (error, _) {
        final message = error is AppException
            ? error.message
            : 'Une erreur est survenue.';
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: AppColors.ardoise),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: AppSpacing.m),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('RÉESSAYER'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Affiche un message métier dans une `SnackBar` d'alerte.
void showErrorSnack(BuildContext context, Object error) {
  final message = error is AppException
      ? error.message
      : 'Une erreur est survenue.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.alerte),
    );
}
