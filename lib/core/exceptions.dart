/// Exceptions métier de l'application.
///
/// Les erreurs techniques (PostgREST, Auth, réseau) sont traduites en
/// exceptions métier par `_translate` dans `supabase_repositories.dart`.
/// Les écrans n'attrapent que ces types-là.
library;

/// Base commune : toute exception métier porte un message affichable.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Identifiants invalides à la connexion.
class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException([
    super.message = 'Email ou mot de passe incorrect.',
  ]);
}

/// Le pseudo demandé est déjà pris (contrainte UNIQUE sur `profiles.username`).
class UsernameTakenException extends AppException {
  const UsernameTakenException([super.message = 'Ce pseudo est déjà utilisé.']);
}

/// L'email est déjà rattaché à un compte.
class EmailAlreadyRegisteredException extends AppException {
  const EmailAlreadyRegisteredException([
    super.message = 'Un compte existe déjà avec cet email.',
  ]);
}

/// Le compte existe mais l'email n'a pas encore été confirmé.
class EmailNotConfirmedException extends AppException {
  const EmailNotConfirmedException([
    super.message =
        'Confirme ton email avant de te connecter (lien reçu par mail).',
  ]);
}

/// Saisie qui ne respecte pas une règle de validation serveur.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Le coup d'envoi est passé : le pronostic n'est plus modifiable (RG-01).
///
/// Correspond au code PostgREST `42501` (violation de politique RLS) sur la
/// table `predictions`.
class PredictionLockedException extends AppException {
  const PredictionLockedException([
    super.message = 'Le match a commencé, le pronostic est verrouillé.',
  ]);
}

/// Aucun groupe ne correspond au code d'invitation saisi (RG-06).
class GroupNotFoundException extends AppException {
  const GroupNotFoundException([
    super.message = 'Aucun groupe trouvé pour ce code.',
  ]);
}

/// L'utilisateur est déjà membre du groupe (contrainte UNIQUE).
class AlreadyMemberException extends AppException {
  const AlreadyMemberException([
    super.message = 'Tu fais déjà partie de ce groupe.',
  ]);
}

/// L'utilisateur n'est pas authentifié alors que l'action l'exige.
class NotAuthenticatedException extends AppException {
  const NotAuthenticatedException([
    super.message = 'Session expirée, reconnecte-toi.',
  ]);
}

/// Panne réseau ou serveur indisponible.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Connexion indisponible. Réessaie plus tard.',
  ]);
}

/// Filet de sécurité : erreur non prévue, déjà tracée côté technique.
class UnexpectedException extends AppException {
  const UnexpectedException([super.message = 'Une erreur est survenue.']);
}
