/// Points d'accès Riverpod.
///
/// Les écrans lisent ces providers ; ils n'instancient jamais un repository
/// ni le client Supabase directement. En test, on surcharge
/// [supabaseClientProvider] ou les `*RepositoryProvider` via
/// `ProviderScope(overrides: [...])`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../repositories/supabase_repositories.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

/// Client Supabase. Surchargé en test par un faux client ou, plus souvent,
/// on surcharge directement les repositories ci-dessous.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return SupabaseMatchRepository(ref.watch(supabaseClientProvider));
});

final predictionRepositoryProvider = Provider<PredictionRepository>((ref) {
  return SupabasePredictionRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(authRepositoryProvider),
  );
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(authRepositoryProvider),
  );
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return SupabaseStatsRepository(ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

/// Profil courant, réémis à chaque changement de session (`null` = déconnecté).
final authStateProvider = StreamProvider<Profile?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Profil courant en synchrone (peut être `null` le temps du premier chargement).
final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Identifiant de l'utilisateur connecté, ou `null`.
///
/// Tous les providers qui lisent des données propres à l'utilisateur (ses
/// groupes, ses pronostics, ses stats) l'observent en première ligne — pas
/// pour sa valeur, mais pour que Riverpod les recalcule automatiquement à
/// chaque connexion/déconnexion. Sans ça, ils gardent en cache les données
/// du compte précédent : sur le web notamment, se déconnecter puis se
/// reconnecter avec un autre compte affichait encore les groupes et les
/// stats de l'ancien utilisateur.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentProfileProvider)?.id;
});

// ---------------------------------------------------------------------------
// Matchs
// ---------------------------------------------------------------------------

/// Matchs à venir et en cours, triés par coup d'envoi.
final upcomingMatchesProvider = FutureProvider<List<MatchView>>((ref) {
  return ref.watch(matchRepositoryProvider).upcomingMatches();
});

/// Un match précis (écran E3).
final matchViewProvider = FutureProvider.family<MatchView, String>((
  ref,
  matchId,
) {
  return ref.watch(matchRepositoryProvider).matchById(matchId);
});

// ---------------------------------------------------------------------------
// Groupes
// ---------------------------------------------------------------------------

/// Groupes de l'utilisateur, avec rang et effectif (écran E4).
final myGroupsProvider = FutureProvider<List<Membership>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(groupRepositoryProvider).myGroups();
});

/// Détail d'un groupe (écran E5).
final groupProvider = FutureProvider.family<Group, String>((ref, groupId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(groupRepositoryProvider).groupById(groupId);
});

/// Classement d'un groupe (écran E5).
final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, groupId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(groupRepositoryProvider).leaderboard(groupId);
    });

/// Historique des pronostics notés du groupe, par membre (écran E5).
final predictionHistoryProvider =
    FutureProvider.family<List<PredictionHistoryEntry>, String>((ref, groupId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(groupRepositoryProvider).predictionHistory(groupId);
    });

// ---------------------------------------------------------------------------
// Pronostics
// ---------------------------------------------------------------------------

/// Pronostics de l'utilisateur, indexés par `matchId` (E2). Un pronostic
/// vaut pour tous ses groupes : pas de distinction par groupe ici.
final myPredictionsProvider = FutureProvider<Map<String, Prediction>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(predictionRepositoryProvider).myPredictions();
});

/// Pronostic de l'utilisateur pour un match précis (E3).
final myPredictionProvider = FutureProvider.family<Prediction?, String>((
  ref,
  matchId,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(predictionRepositoryProvider).myPrediction(matchId);
});

/// Clé composite groupe + match, pour les pronostics des autres membres.
typedef GroupMatchKey = ({String groupId, String matchId});

/// Pronostics des autres membres d'un groupe pour un match (E3, visibles
/// après le coup d'envoi seulement — RG-08).
final groupPredictionsProvider =
    FutureProvider.family<List<GroupPrediction>, GroupMatchKey>((ref, key) {
      ref.watch(currentUserIdProvider);
      return ref
          .watch(predictionRepositoryProvider)
          .groupPredictions(groupId: key.groupId, matchId: key.matchId);
    });

/// Les 10 derniers pronostics de l'utilisateur, tous groupes confondus (E6).
final myRecentPredictionsProvider = FutureProvider<List<RecentPrediction>>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(predictionRepositoryProvider).myRecentPredictions();
});

// ---------------------------------------------------------------------------
// Statistiques
// ---------------------------------------------------------------------------

/// Statistiques personnelles agrégées (écran E6).
final myStatsProvider = FutureProvider<MyStats>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(statsRepositoryProvider).myStats();
});
