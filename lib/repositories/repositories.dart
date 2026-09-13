/// Interfaces d'accès aux données.
///
/// Aucun écran n'appelle Supabase directement : il passe par un provider qui
/// expose l'une de ces interfaces. C'est ce qui rend l'application testable
/// sans base, via `ProviderScope(overrides: [...])`.
library;

import '../models/models.dart';

/// Authentification et profil de l'utilisateur courant.
abstract interface class AuthRepository {
  /// Émet le profil courant à chaque changement de session (`null` = déconnecté).
  Stream<Profile?> authStateChanges();

  /// Profil courant si une session est active, sinon `null`.
  Profile? get currentProfile;

  /// Identifiant de l'utilisateur courant, sinon `null`.
  String? get currentUserId;

  /// Connexion par email / mot de passe.
  ///
  /// Lève [InvalidCredentialsException] si le couple est refusé.
  Future<Profile> signIn({required String email, required String password});

  /// Création de compte. Le pseudo est passé dans `data` : le trigger serveur
  /// crée la ligne `profiles`.
  ///
  /// Renvoie le profil si une session est ouverte immédiatement, ou `null` si
  /// une confirmation d'email est requise avant connexion.
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String username,
  });

  Future<void> signOut();

  /// Met à jour le pseudo affiché (écran E6).
  Future<Profile> updateUsername(String username);

  /// Met à jour le sticker et la couleur d'avatar (écran E6).
  Future<Profile> updateAvatar({
    required String avatarIcon,
    required String avatarColor,
  });
}

/// Catalogue sportif en lecture seule : compétitions, équipes, matchs.
abstract interface class MatchRepository {
  /// Matchs à venir et en cours, triés par coup d'envoi croissant.
  Future<List<MatchView>> upcomingMatches();

  /// Un match précis, enrichi de ses équipes et de sa compétition.
  Future<MatchView> matchById(String matchId);
}

/// Pronostics de l'utilisateur et des groupes.
///
/// Un pronostic se saisit une seule fois pour un match et vaut pour tous les
/// groupes de l'utilisateur (une ligne par groupe en base — le barème
/// diffère par groupe — mais une seule action côté client). Une fois posé,
/// il n'est ni modifiable ni supprimable.
abstract interface class PredictionRepository {
  /// Pronostics de l'utilisateur, indexés par `matchId` (écran E2).
  Future<Map<String, Prediction>> myPredictions();

  /// Pronostic de l'utilisateur pour un match, ou `null` s'il n'a pas encore
  /// pronostiqué (écran E3).
  Future<Prediction?> myPrediction(String matchId);

  /// Crée le pronostic d'un match, répliqué sur tous les groupes de
  /// l'utilisateur (RG-02 : une ligne par groupe/membre/match).
  ///
  /// Lève [PredictionLockedException] si le coup d'envoi est passé (RG-01,
  /// refus RLS `42501`). N'a aucun effet de mise à jour : appeler cette
  /// méthode une seconde fois pour le même match échoue (contrainte UNIQUE).
  Future<void> createPrediction({
    required String matchId,
    required int homeScore,
    required int awayScore,
  });

  /// Pronostics des autres membres d'un groupe pour un match (RG-08 :
  /// visibles seulement après le coup d'envoi ; la RLS filtre, la liste peut
  /// donc être vide).
  Future<List<GroupPrediction>> groupPredictions({
    required String groupId,
    required String matchId,
  });

  /// Les [limit] derniers pronostics de l'utilisateur, tous groupes
  /// confondus (un match compte une fois même s'il a été prédit dans
  /// plusieurs groupes), du plus récent au plus ancien (écran E6).
  Future<List<RecentPrediction>> myRecentPredictions({int limit = 10});
}

/// Groupes : liste, création, adhésion, classement.
abstract interface class GroupRepository {
  /// Groupes de l'utilisateur courant, avec son rang dans chacun (écran E4).
  Future<List<Membership>> myGroups();

  /// Détail d'un groupe dont l'utilisateur est membre (écran E5).
  Future<Group> groupById(String groupId);

  /// Crée un groupe. Le créateur devient admin (trigger), le code est généré
  /// par la base (RG-06). Renvoie le groupe créé.
  Future<Group> createGroup({
    required String name,
    String? description,
    int pointsExact,
    int pointsResult,
    String avatarIcon,
    String avatarColor,
  });

  /// Recherche un groupe par code d'invitation exact (RG-06), sans y adhérer.
  ///
  /// Lève [GroupNotFoundException] si aucun groupe ne correspond.
  Future<GroupSummary> findByCode(String code);

  /// Rejoint un groupe via son code d'invitation.
  ///
  /// Lève [AlreadyMemberException] si l'utilisateur en est déjà membre.
  Future<Group> joinByCode(String code);

  /// Classement d'un groupe (RG-10 : départage serveur au nombre de scores
  /// exacts).
  Future<List<LeaderboardEntry>> leaderboard(String groupId);

  /// Historique des pronostics déjà notés du groupe, un par membre et par
  /// match noté (`points_earned` non nul — RG-05). Visible seulement si
  /// [Group.showPredictionHistory] est activé.
  Future<List<PredictionHistoryEntry>> predictionHistory(String groupId);

  /// Modifie les paramètres d'un groupe (nom, description, barème, sticker,
  /// affichage de l'historique).
  ///
  /// Réservé à l'administrateur — refusé par la RLS sinon.
  Future<Group> updateGroupSettings({
    required String groupId,
    required String name,
    String? description,
    required int pointsExact,
    required int pointsResult,
    required String avatarIcon,
    required String avatarColor,
    required bool showPredictionHistory,
  });

  /// Quitte un groupe. Si l'utilisateur est l'administrateur, le rôle est
  /// transmis au membre le plus ancien (RG-11, trigger serveur).
  Future<void> leaveGroup(String groupId);

  /// Retire un membre du groupe. Réservé à l'administrateur.
  Future<void> removeMember({
    required String groupId,
    required String profileId,
  });
}

/// Statistiques personnelles agrégées (écran E6).
abstract interface class StatsRepository {
  Future<MyStats> myStats();
}
