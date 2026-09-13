/// Implémentations des repositories au-dessus de Supabase.
///
/// Toute erreur technique (Auth, PostgREST, réseau) est convertie en
/// [AppException] par [translateError] avant de remonter aux providers. Les
/// écrans ne voient jamais un `PostgrestException`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/exceptions.dart';
import '../models/models.dart';
import 'repositories.dart';

// ---------------------------------------------------------------------------
// Traduction des erreurs techniques → exceptions métier
// ---------------------------------------------------------------------------

/// Convertit une erreur technique en [AppException] affichable.
///
/// Règle du dossier : le code PostgREST `42501` (violation de politique RLS)
/// devient [PredictionLockedException]. Ce code peut en réalité venir de
/// n'importe quelle table — c'est pourquoi le détail réel (table, message)
/// est affiché en plus en mode debug, pour ne jamais avoir à deviner.
AppException translateError(Object error) {
  if (error is AppException) return error;

  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login')) {
      return const InvalidCredentialsException();
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return const EmailAlreadyRegisteredException();
    }
    if (message.contains('not confirmed')) {
      return const EmailNotConfirmedException();
    }
    if (message.contains('weak password') || message.contains('password')) {
      return const ValidationException(
        'Mot de passe trop court (8 caractères minimum).',
      );
    }
    return InvalidCredentialsException(
      kDebugMode
          ? 'Auth (${error.code ?? error.statusCode}) : ${error.message}'
          : 'Email ou mot de passe incorrect.',
    );
  }

  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        // Ce code signale un refus RLS générique — pas forcément un
        // pronostic verrouillé. En debug, on affiche le détail réel pour
        // ne pas masquer la table/policy réellement en cause.
        return PredictionLockedException(
          kDebugMode
              ? 'RLS 42501 (${error.details ?? error.hint ?? '-'}) : '
                    '${error.message}'
              : 'Le match a commencé, le pronostic est verrouillé.',
        );
      case '23505':
        return const ValidationException('Cette donnée existe déjà.');
      case '23514':
        return const ValidationException('Valeur hors des limites autorisées.');
      case 'PGRST116':
        return const UnexpectedException('Élément introuvable.');
    }
    return UnexpectedException(
      kDebugMode
          ? 'PostgREST (${error.code}) : ${error.message}'
          : 'Une erreur est survenue.',
    );
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('clientexception') ||
      text.contains('connection') ||
      text.contains('timeout')) {
    return const NetworkException();
  }

  return UnexpectedException(
    kDebugMode ? '${error.runtimeType} : $error' : 'Une erreur est survenue.',
  );
}

/// Exécute [action] en convertissant toute erreur via [translateError].
Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw translateError(error);
  }
}

// ---------------------------------------------------------------------------
// AuthRepository
// ---------------------------------------------------------------------------

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  Profile? _cachedProfile;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Profile? get currentProfile => _cachedProfile;

  @override
  Stream<Profile?> authStateChanges() async* {
    yield await _loadProfile();
    await for (final state in _auth.onAuthStateChange) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          yield await _loadProfile();
        case AuthChangeEvent.signedOut:
          _cachedProfile = null;
          yield null;
        default:
          break;
      }
    }
  }

  @override
  Future<Profile> signIn({required String email, required String password}) {
    return _guard(() async {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      // Le trigger `handle_new_user` crée la ligne `profiles` au moment de
      // l'inscription ; un second essai après une courte pause absorbe un
      // éventuel décalage de réplication plutôt que d'échouer tout de suite.
      var profile = await _loadProfile();
      if (profile == null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        profile = await _loadProfile();
      }
      if (profile == null) {
        throw const UnexpectedException(
          'Connexion réussie mais aucun profil trouvé pour ce compte. '
          'Vérifie que le trigger de création de profil est actif côté '
          'Supabase (table profiles).',
        );
      }
      return profile;
    });
  }

  @override
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String username,
  }) {
    return _guard(() async {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim()},
      );
      // Pas de session ⇒ confirmation d'email requise avant connexion.
      if (response.session == null) return null;
      return _loadProfile();
    });
  }

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  @override
  Future<Profile> updateUsername(String username) {
    return _guard(() async {
      final userId = currentUserId;
      if (userId == null) throw const NotAuthenticatedException();
      try {
        final row = await _client
            .from('profiles')
            .update({'username': username.trim()})
            .eq('id', userId)
            .select()
            .single();
        final profile = Profile.fromJson(row);
        _cachedProfile = profile;
        return profile;
      } on PostgrestException catch (error) {
        if (error.code == '23505') throw const UsernameTakenException();
        rethrow;
      }
    });
  }

  @override
  Future<Profile> updateAvatar({
    required String avatarIcon,
    required String avatarColor,
  }) {
    return _guard(() async {
      final userId = currentUserId;
      if (userId == null) throw const NotAuthenticatedException();
      final row = await _client
          .from('profiles')
          .update({'avatar_icon': avatarIcon, 'avatar_color': avatarColor})
          .eq('id', userId)
          .select()
          .single();
      final profile = Profile.fromJson(row);
      _cachedProfile = profile;
      return profile;
    });
  }

  Future<Profile?> _loadProfile() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) {
      _cachedProfile = null;
      return null;
    }
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    _cachedProfile = row == null ? null : Profile.fromJson(row);
    return _cachedProfile;
  }
}

// ---------------------------------------------------------------------------
// MatchRepository
// ---------------------------------------------------------------------------

/// Colonnes imbriquées PostgREST : les deux équipes + la compétition.
/// La désambiguïsation `teams!home_team_id` est nécessaire car `matches`
/// référence `teams` deux fois.
const String _matchSelect =
    '*, home_team:teams!home_team_id(*), away_team:teams!away_team_id(*), '
    'league:leagues!league_id(*)';

class SupabaseMatchRepository implements MatchRepository {
  SupabaseMatchRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MatchView>> upcomingMatches() {
    return _guard(() async {
      final rows = await _client
          .from('matches')
          .select(_matchSelect)
          .inFilter('status', ['scheduled', 'live'])
          .order('kickoff_at', ascending: true);
      return rows.map((row) => MatchView.fromJson(row)).toList(growable: false);
    });
  }

  @override
  Future<MatchView> matchById(String matchId) {
    return _guard(() async {
      final row = await _client
          .from('matches')
          .select(_matchSelect)
          .eq('id', matchId)
          .single();
      return MatchView.fromJson(row);
    });
  }
}

// ---------------------------------------------------------------------------
// PredictionRepository
// ---------------------------------------------------------------------------

class SupabasePredictionRepository implements PredictionRepository {
  SupabasePredictionRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthRepository _auth;

  String get _userId {
    final id = _auth.currentUserId;
    if (id == null) throw const NotAuthenticatedException();
    return id;
  }

  @override
  Future<Map<String, Prediction>> myPredictions() {
    return _guard(() async {
      // Un pronostic est répliqué sur tous les groupes (même score) : une
      // ligne par match_id suffit pour cet affichage groupé par jour (E2).
      final rows = await _client
          .from('predictions')
          .select()
          .eq('profile_id', _userId);
      return {
        for (final row in rows)
          row['match_id'] as String: Prediction.fromJson(row),
      };
    });
  }

  @override
  Future<Prediction?> myPrediction(String matchId) {
    return _guard(() async {
      final row = await _client
          .from('predictions')
          .select()
          .eq('profile_id', _userId)
          .eq('match_id', matchId)
          .limit(1)
          .maybeSingle();
      return row == null ? null : Prediction.fromJson(row);
    });
  }

  @override
  Future<void> createPrediction({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) {
    return _guard(() async {
      final groupRows = await _client
          .from('group_members')
          .select('group_id')
          .eq('profile_id', _userId);
      final groupIds = groupRows.map((row) => row['group_id'] as String);
      if (groupIds.isEmpty) {
        throw const ValidationException('Rejoins un groupe pour pronostiquer.');
      }
      // Une seule requête, une ligne par groupe : soit tout est enregistré,
      // soit rien (RG-02, contrainte UNIQUE par groupe/membre/match).
      await _client.from('predictions').insert([
        for (final groupId in groupIds)
          {
            'group_id': groupId,
            'profile_id': _userId,
            'match_id': matchId,
            'home_score_pred': homeScore,
            'away_score_pred': awayScore,
          },
      ]);
    });
  }

  @override
  Future<List<GroupPrediction>> groupPredictions({
    required String groupId,
    required String matchId,
  }) {
    return _guard(() async {
      final rows = await _client
          .from('predictions')
          .select(
            'profile_id, home_score_pred, away_score_pred, points_earned, '
            'profile:profiles!profile_id(username, avatar_icon, avatar_color)',
          )
          .eq('group_id', groupId)
          .eq('match_id', matchId);
      return rows
          .map((row) => GroupPrediction.fromJson(row))
          .toList(growable: false);
    });
  }

  @override
  Future<List<RecentPrediction>> myRecentPredictions({int limit = 10}) {
    return _guard(() async {
      // Un même match est répliqué sur chaque groupe de l'utilisateur : on
      // sur-échantillonne puis on ne garde qu'une ligne par match, en
      // conservant l'ordre du plus récent au plus ancien.
      final rows = await _client
          .from('predictions')
          .select('''
            match_id, home_score_pred, away_score_pred, points_earned,
            match:matches!match_id(
              kickoff_at, status, home_score, away_score,
              home_team:teams!home_team_id(short_name),
              away_team:teams!away_team_id(short_name)
            )
          ''')
          .eq('profile_id', _userId)
          .order('created_at', ascending: false)
          .limit(limit * 20);

      final seenMatches = <String>{};
      final result = <RecentPrediction>[];
      for (final row in rows) {
        final matchId = row['match_id'] as String;
        if (!seenMatches.add(matchId)) continue;
        result.add(RecentPrediction.fromJson(row));
        if (result.length >= limit) break;
      }
      return result;
    });
  }
}

// ---------------------------------------------------------------------------
// GroupRepository
// ---------------------------------------------------------------------------

class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthRepository _auth;

  String get _userId {
    final id = _auth.currentUserId;
    if (id == null) throw const NotAuthenticatedException();
    return id;
  }

  @override
  Future<List<Membership>> myGroups() {
    return _guard(() async {
      final rows = await _client
          .from('group_members')
          .select('*, group:groups!group_id(*)')
          .eq('profile_id', _userId);

      final memberships = <Membership>[];
      for (final row in rows) {
        final member = GroupMember.fromJson(row);
        final group = Group.fromJson(row['group'] as Map<String, dynamic>);
        // Rang et effectif via la fonction serveur (départage RG-10 inclus).
        final board = await leaderboard(group.id);
        final mine = board.where((e) => e.profileId == _userId).firstOrNull;
        memberships.add(
          Membership(
            member: member,
            group: group,
            rank: mine?.rank ?? board.length + 1,
            memberCount: board.length,
          ),
        );
      }
      memberships.sort(
        (a, b) =>
            a.group.name.toLowerCase().compareTo(b.group.name.toLowerCase()),
      );
      return memberships;
    });
  }

  @override
  Future<Group> groupById(String groupId) {
    return _guard(() async {
      final row = await _client
          .from('groups')
          .select()
          .eq('id', groupId)
          .single();
      return Group.fromJson(row);
    });
  }

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    int pointsExact = 3,
    int pointsResult = 1,
    String avatarIcon = 'ball',
    String avatarColor = '#FFB020',
  }) {
    return _guard(() async {
      final trimmedDescription = description?.trim();
      // Passe par une fonction plutôt qu'un insert + select direct : la RLS
      // vérifierait l'appartenance au groupe (groups_select_member) avant
      // que le trigger admin (handle_new_group, AFTER INSERT) n'ait eu le
      // temps de créer la ligne group_members correspondante.
      final result = await _client.rpc(
        'create_group',
        params: {
          'p_name': name.trim(),
          'p_description': (trimmedDescription?.isEmpty ?? true)
              ? null
              : trimmedDescription,
          'p_points_exact': pointsExact,
          'p_points_result': pointsResult,
          'p_avatar_icon': avatarIcon,
          'p_avatar_color': avatarColor,
        },
      );
      final row = result is List
          ? result.cast<Map<String, dynamic>>().first
          : result as Map<String, dynamic>;
      return Group.fromJson(row);
    });
  }

  @override
  Future<GroupSummary> findByCode(String code) {
    return _guard(() async {
      final result = await _client.rpc(
        'find_group_by_code',
        params: {'p_code': code.trim().toUpperCase()},
      );
      final rows = (result as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) throw const GroupNotFoundException();
      return GroupSummary.fromJson(rows.first);
    });
  }

  @override
  Future<Group> joinByCode(String code) {
    return _guard(() async {
      final summary = await findByCode(code);
      try {
        await _client.from('group_members').insert({
          'group_id': summary.id,
          'profile_id': _userId,
        });
      } on PostgrestException catch (error) {
        if (error.code == '23505') throw const AlreadyMemberException();
        rethrow;
      }
      return groupById(summary.id);
    });
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(String groupId) {
    return _guard(() async {
      final result = await _client.rpc(
        'group_leaderboard',
        params: {'p_group_id': groupId},
      );
      return (result as List)
          .cast<Map<String, dynamic>>()
          .map((row) => LeaderboardEntry.fromJson(row))
          .toList(growable: false);
    });
  }

  @override
  Future<List<PredictionHistoryEntry>> predictionHistory(String groupId) {
    return _guard(() async {
      final rows = await _client
          .from('predictions')
          .select('''
            profile_id, home_score_pred, away_score_pred, points_earned,
            profile:profiles!profile_id(username, avatar_icon, avatar_color),
            match:matches!match_id(
              kickoff_at, home_score, away_score,
              home_team:teams!home_team_id(short_name),
              away_team:teams!away_team_id(short_name)
            )
          ''')
          .eq('group_id', groupId)
          .not('points_earned', 'is', null);
      final entries = rows
          .map((row) => PredictionHistoryEntry.fromJson(row))
          .toList();
      // Le plus récent d'abord ; tri client, l'ordre sur un champ imbriqué
      // n'est pas garanti par le select ci-dessus.
      entries.sort((a, b) => b.kickoffAt.compareTo(a.kickoffAt));
      return entries;
    });
  }

  @override
  Future<Group> updateGroupSettings({
    required String groupId,
    required String name,
    String? description,
    required int pointsExact,
    required int pointsResult,
    required String avatarIcon,
    required String avatarColor,
    required bool showPredictionHistory,
  }) {
    return _guard(() async {
      final trimmedDescription = description?.trim();
      // Pas de risque de conflit RETURNING-vs-trigger ici : l'appelant est
      // déjà membre du groupe avant cette mise à jour (contrairement à
      // createGroup), la RLS le sait donc déjà au moment du RETURNING.
      final row = await _client
          .from('groups')
          .update({
            'name': name.trim(),
            'description': (trimmedDescription?.isEmpty ?? true)
                ? null
                : trimmedDescription,
            'points_exact': pointsExact,
            'points_result': pointsResult,
            'avatar_icon': avatarIcon,
            'avatar_color': avatarColor,
            'show_prediction_history': showPredictionHistory,
          })
          .eq('id', groupId)
          .select()
          .single();
      return Group.fromJson(row);
    });
  }

  @override
  Future<void> leaveGroup(String groupId) {
    return _guard(() async {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('profile_id', _userId);
    });
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String profileId,
  }) {
    return _guard(() async {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('profile_id', profileId);
    });
  }
}

// ---------------------------------------------------------------------------
// StatsRepository
// ---------------------------------------------------------------------------

class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MyStats> myStats() {
    return _guard(() async {
      final result = await _client.rpc('my_stats');
      final data = result is List
          ? (result.isEmpty ? null : result.first as Map<String, dynamic>)
          : result as Map<String, dynamic>?;
      return data == null ? MyStats.empty : MyStats.fromJson(data);
    });
  }
}
