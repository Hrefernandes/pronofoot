/// Modèles de données — objets immuables, un par relation du MLD, plus
/// quelques agrégats de lecture (`MatchView`, `LeaderboardEntry`, ...).
///
/// Aucune dépendance à Supabase ici : les `fromJson` acceptent de simples
/// `Map<String, dynamic>` pour rester testables et réutilisables.
library;

// ---------------------------------------------------------------------------
// Types énumérés
// ---------------------------------------------------------------------------

/// `match_status` : cycle de vie d'un match.
enum MatchStatus {
  scheduled,
  live,
  finished;

  static MatchStatus fromDb(String value) => switch (value) {
    'scheduled' => MatchStatus.scheduled,
    'live' => MatchStatus.live,
    'finished' => MatchStatus.finished,
    _ => MatchStatus.scheduled,
  };

  String get db => name;

  bool get isFinished => this == MatchStatus.finished;
  bool get isLive => this == MatchStatus.live;
  bool get isScheduled => this == MatchStatus.scheduled;
}

/// `member_role` : droits d'un membre au sein d'un groupe.
enum MemberRole {
  admin,
  member;

  static MemberRole fromDb(String value) =>
      value == 'admin' ? MemberRole.admin : MemberRole.member;

  String get db => name;

  bool get isAdmin => this == MemberRole.admin;
}

// ---------------------------------------------------------------------------
// profiles
// ---------------------------------------------------------------------------

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.avatarIcon,
    required this.avatarColor,
    required this.createdAt,
    this.displayName,
  });

  final String id;
  final String username;
  final String? displayName;
  final String avatarIcon;
  final String avatarColor;
  final DateTime createdAt;

  /// Nom à afficher : `display_name` s'il existe, sinon le pseudo.
  String get name => (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : username;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarIcon: json['avatar_icon'] as String? ?? 'ball',
    avatarColor: json['avatar_color'] as String? ?? '#FFB020',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  @override
  bool operator ==(Object other) => other is Profile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// leagues
// ---------------------------------------------------------------------------

class League {
  const League({
    required this.id,
    required this.name,
    required this.country,
    required this.colorPrimary,
    required this.colorSecondary,
    required this.colorText,
  });

  final String id;
  final String name;
  final String country;
  final String colorPrimary;
  final String colorSecondary;
  final String colorText;

  factory League.fromJson(Map<String, dynamic> json) => League(
    id: json['id'] as String,
    name: json['name'] as String,
    country: json['country'] as String? ?? '',
    colorPrimary: json['color_primary'] as String? ?? '#16203A',
    colorSecondary: json['color_secondary'] as String? ?? '#1E2A47',
    colorText: json['color_text'] as String? ?? '#F2F5FF',
  );

  @override
  bool operator ==(Object other) => other is League && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// teams
// ---------------------------------------------------------------------------

class Team {
  const Team({
    required this.id,
    required this.leagueId,
    required this.shortName,
    required this.name,
    required this.colorPrimary,
    required this.colorSecondary,
    required this.colorText,
  });

  final String id;
  final String leagueId;

  /// 2 à 5 caractères — sert au monogramme.
  final String shortName;
  final String name;
  final String colorPrimary;
  final String colorSecondary;
  final String colorText;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    leagueId: json['league_id'] as String? ?? '',
    shortName: json['short_name'] as String? ?? '?',
    name: json['name'] as String? ?? '',
    colorPrimary: json['color_primary'] as String? ?? '#16203A',
    colorSecondary: json['color_secondary'] as String? ?? '#1E2A47',
    colorText: json['color_text'] as String? ?? '#F2F5FF',
  );

  @override
  bool operator ==(Object other) => other is Team && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// matches (+ agrégat de lecture MatchView)
// ---------------------------------------------------------------------------

class Match {
  const Match({
    required this.id,
    required this.leagueId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoffAt,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final String leagueId;
  final String homeTeamId;
  final String awayTeamId;
  final DateTime kickoffAt;
  final int? homeScore;
  final int? awayScore;
  final MatchStatus status;

  /// RG-01 (confort UI) : le pronostic reste ouvert tant que le coup d'envoi
  /// n'est pas passé. La règle stricte est appliquée côté serveur (RLS).
  bool isOpenForPrediction({DateTime? now}) =>
      status.isScheduled &&
      kickoffAt.toUtc().isAfter((now ?? DateTime.now()).toUtc());

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'] as String,
    leagueId: json['league_id'] as String,
    homeTeamId: json['home_team_id'] as String,
    awayTeamId: json['away_team_id'] as String,
    kickoffAt: DateTime.parse(json['kickoff_at'] as String),
    homeScore: json['home_score'] as int?,
    awayScore: json['away_score'] as int?,
    status: MatchStatus.fromDb(json['status'] as String? ?? 'scheduled'),
  );
}

/// Match enrichi de ses deux équipes et de sa compétition.
///
/// Construit à partir d'un `select` PostgREST imbriqué. C'est la forme
/// consommée par les écrans E2 et E3.
class MatchView {
  const MatchView({
    required this.match,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
  });

  final Match match;
  final Team homeTeam;
  final Team awayTeam;
  final League league;

  String get id => match.id;
  DateTime get kickoffAt => match.kickoffAt;
  MatchStatus get status => match.status;

  factory MatchView.fromJson(Map<String, dynamic> json) => MatchView(
    match: Match.fromJson(json),
    homeTeam: Team.fromJson(_nested(json, 'home_team')),
    awayTeam: Team.fromJson(_nested(json, 'away_team')),
    league: League.fromJson(_nested(json, 'league')),
  );

  static Map<String, dynamic> _nested(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map) {
      return value.first as Map<String, dynamic>;
    }
    return const <String, dynamic>{};
  }
}

// ---------------------------------------------------------------------------
// groups
// ---------------------------------------------------------------------------

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.pointsExact,
    required this.pointsResult,
    required this.createdAt,
    this.description,
    this.updatedAt,
    this.avatarIcon = 'ball',
    this.avatarColor = '#FFB020',
    this.showPredictionHistory = true,
  });

  final String id;
  final String name;
  final String? description;
  final String inviteCode;

  /// Barème (RG-04) : points_exact > points_result (contrainte CHECK).
  final int pointsExact;
  final int pointsResult;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Sticker du groupe (voir `lib/core/stickers.dart`).
  final String avatarIcon;
  final String avatarColor;

  /// Paramètre du groupe : l'historique des pronostics par membre (E5) est-il
  /// affiché ? Réglable par l'admin.
  final bool showPredictionHistory;

  /// `3 pts / 1 pt`
  String get scoringLabel => '$pointsExact pts / $pointsResult pt';

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    inviteCode: json['invite_code'] as String? ?? '',
    pointsExact: json['points_exact'] as int? ?? 3,
    pointsResult: json['points_result'] as int? ?? 1,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
    avatarIcon: json['avatar_icon'] as String? ?? 'ball',
    avatarColor: json['avatar_color'] as String? ?? '#FFB020',
    showPredictionHistory: json['show_prediction_history'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) => other is Group && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// group_members (+ agrégat Membership pour la liste E4)
// ---------------------------------------------------------------------------

class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.profileId,
    required this.role,
    required this.totalPoints,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final String profileId;
  final MemberRole role;

  /// Écriture serveur uniquement.
  final int totalPoints;
  final DateTime joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    profileId: json['profile_id'] as String,
    role: MemberRole.fromDb(json['role'] as String? ?? 'member'),
    totalPoints: json['total_points'] as int? ?? 0,
    joinedAt: DateTime.parse(json['joined_at'] as String),
  );
}

/// Appartenance de l'utilisateur courant à un groupe : la ligne
/// `group_members` + le `Group` associé + le rang courant.
///
/// Alimente la liste « Mes groupes » (E4).
class Membership {
  const Membership({
    required this.member,
    required this.group,
    required this.rank,
    required this.memberCount,
  });

  final GroupMember member;
  final Group group;
  final int rank;
  final int memberCount;

  String get groupId => group.id;
  MemberRole get role => member.role;
  int get totalPoints => member.totalPoints;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    member: GroupMember.fromJson(json),
    group: Group.fromJson(json['group'] as Map<String, dynamic>),
    rank: json['rank'] as int? ?? 0,
    memberCount: json['member_count'] as int? ?? 0,
  );
}

// ---------------------------------------------------------------------------
// predictions
// ---------------------------------------------------------------------------

class Prediction {
  const Prediction({
    required this.id,
    required this.groupId,
    required this.profileId,
    required this.matchId,
    required this.homeScorePred,
    required this.awayScorePred,
    required this.createdAt,
    this.pointsEarned,
    this.updatedAt,
  });

  final String id;
  final String groupId;
  final String profileId;
  final String matchId;
  final int homeScorePred;
  final int awayScorePred;

  /// RG-05 : `null` = non calculé, `0` = calculé sans point.
  final int? pointsEarned;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isScored => pointsEarned != null;

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    profileId: json['profile_id'] as String,
    matchId: json['match_id'] as String,
    homeScorePred: json['home_score_pred'] as int,
    awayScorePred: json['away_score_pred'] as int,
    pointsEarned: json['points_earned'] as int?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
  );
}

/// Pronostic d'un autre membre, tel qu'affiché sur E3 après le coup d'envoi
/// (RG-08). Le pseudo et l'avatar sont joints pour l'affichage.
class GroupPrediction {
  const GroupPrediction({
    required this.profileId,
    required this.username,
    required this.avatarIcon,
    required this.avatarColor,
    required this.homeScorePred,
    required this.awayScorePred,
    this.pointsEarned,
  });

  final String profileId;
  final String username;
  final String avatarIcon;
  final String avatarColor;
  final int homeScorePred;
  final int awayScorePred;
  final int? pointsEarned;

  factory GroupPrediction.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    return GroupPrediction(
      profileId: json['profile_id'] as String,
      username: profile['username'] as String? ?? '?',
      avatarIcon: profile['avatar_icon'] as String? ?? 'ball',
      avatarColor: profile['avatar_color'] as String? ?? '#FFB020',
      homeScorePred: json['home_score_pred'] as int,
      awayScorePred: json['away_score_pred'] as int,
      pointsEarned: json['points_earned'] as int?,
    );
  }
}

/// Une ligne de l'historique des pronostics d'un groupe (E5) : le pronostic
/// d'un membre sur un match déjà noté (`points_earned` non nul, RG-05).
class PredictionHistoryEntry {
  const PredictionHistoryEntry({
    required this.profileId,
    required this.username,
    required this.avatarIcon,
    required this.avatarColor,
    required this.homeTeamShort,
    required this.awayTeamShort,
    required this.kickoffAt,
    required this.actualHomeScore,
    required this.actualAwayScore,
    required this.predHome,
    required this.predAway,
    required this.pointsEarned,
  });

  final String profileId;
  final String username;
  final String avatarIcon;
  final String avatarColor;
  final String homeTeamShort;
  final String awayTeamShort;
  final DateTime kickoffAt;
  final int actualHomeScore;
  final int actualAwayScore;
  final int predHome;
  final int predAway;
  final int pointsEarned;

  factory PredictionHistoryEntry.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    final match = json['match'] as Map<String, dynamic>? ?? const {};
    final homeTeam = match['home_team'] as Map<String, dynamic>? ?? const {};
    final awayTeam = match['away_team'] as Map<String, dynamic>? ?? const {};
    return PredictionHistoryEntry(
      profileId: json['profile_id'] as String,
      username: profile['username'] as String? ?? '?',
      avatarIcon: profile['avatar_icon'] as String? ?? 'ball',
      avatarColor: profile['avatar_color'] as String? ?? '#FFB020',
      homeTeamShort: homeTeam['short_name'] as String? ?? '?',
      awayTeamShort: awayTeam['short_name'] as String? ?? '?',
      kickoffAt: DateTime.parse(match['kickoff_at'] as String),
      actualHomeScore: match['home_score'] as int? ?? 0,
      actualAwayScore: match['away_score'] as int? ?? 0,
      predHome: json['home_score_pred'] as int,
      predAway: json['away_score_pred'] as int,
      pointsEarned: json['points_earned'] as int? ?? 0,
    );
  }
}

/// Un pronostic de l'utilisateur courant, pour son propre historique (E6) —
/// contrairement à [PredictionHistoryEntry], inclut les matchs pas encore
/// joués (`pointsEarned` et les scores réels restent alors `null`).
class RecentPrediction {
  const RecentPrediction({
    required this.matchId,
    required this.homeTeamShort,
    required this.awayTeamShort,
    required this.kickoffAt,
    required this.matchStatus,
    required this.predHome,
    required this.predAway,
    this.actualHomeScore,
    this.actualAwayScore,
    this.pointsEarned,
  });

  final String matchId;
  final String homeTeamShort;
  final String awayTeamShort;
  final DateTime kickoffAt;
  final MatchStatus matchStatus;
  final int predHome;
  final int predAway;
  final int? actualHomeScore;
  final int? actualAwayScore;
  final int? pointsEarned;

  factory RecentPrediction.fromJson(Map<String, dynamic> json) {
    final match = json['match'] as Map<String, dynamic>? ?? const {};
    final homeTeam = match['home_team'] as Map<String, dynamic>? ?? const {};
    final awayTeam = match['away_team'] as Map<String, dynamic>? ?? const {};
    return RecentPrediction(
      matchId: json['match_id'] as String,
      homeTeamShort: homeTeam['short_name'] as String? ?? '?',
      awayTeamShort: awayTeam['short_name'] as String? ?? '?',
      kickoffAt: DateTime.parse(match['kickoff_at'] as String),
      matchStatus: MatchStatus.fromDb(
        match['status'] as String? ?? 'scheduled',
      ),
      predHome: json['home_score_pred'] as int,
      predAway: json['away_score_pred'] as int,
      actualHomeScore: match['home_score'] as int?,
      actualAwayScore: match['away_score'] as int?,
      pointsEarned: json['points_earned'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Retours de fonctions RPC
// ---------------------------------------------------------------------------

/// `group_leaderboard` — une ligne du classement (RG-10 : départage au
/// nombre de scores exacts, déjà appliqué côté serveur).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.profileId,
    required this.username,
    required this.avatarIcon,
    required this.avatarColor,
    required this.totalPoints,
    required this.exactScores,
    required this.rank,
  });

  final String profileId;
  final String username;
  final String avatarIcon;
  final String avatarColor;
  final int totalPoints;
  final int exactScores;
  final int rank;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        profileId: json['profile_id'] as String,
        username: json['username'] as String? ?? '?',
        avatarIcon: json['avatar_icon'] as String? ?? 'ball',
        avatarColor: json['avatar_color'] as String? ?? '#FFB020',
        totalPoints: json['total_points'] as int? ?? 0,
        exactScores: json['exact_scores'] as int? ?? 0,
        rank: json['rank'] as int? ?? 0,
      );
}

/// `find_group_by_code` — aperçu d'un groupe avant de le rejoindre.
class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    this.avatarIcon = 'ball',
    this.avatarColor = '#FFB020',
  });

  final String id;
  final String name;
  final int memberCount;
  final String avatarIcon;
  final String avatarColor;

  factory GroupSummary.fromJson(Map<String, dynamic> json) => GroupSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    memberCount: json['member_count'] as int? ?? 0,
    avatarIcon: json['avatar_icon'] as String? ?? 'ball',
    avatarColor: json['avatar_color'] as String? ?? '#FFB020',
  );
}

/// `my_stats` — statistiques personnelles agrégées (écran E6).
class MyStats {
  const MyStats({
    required this.totalPredictions,
    required this.exactScores,
    required this.correctOutcomes,
    required this.totalPoints,
    required this.successRate,
  });

  final int totalPredictions;
  final int exactScores;
  final int correctOutcomes;
  final int totalPoints;

  /// Taux de réussite en pourcentage entier (0 à 100).
  final int successRate;

  static const empty = MyStats(
    totalPredictions: 0,
    exactScores: 0,
    correctOutcomes: 0,
    totalPoints: 0,
    successRate: 0,
  );

  factory MyStats.fromJson(Map<String, dynamic> json) => MyStats(
    totalPredictions: json['total_predictions'] as int? ?? 0,
    exactScores: json['exact_scores'] as int? ?? 0,
    correctOutcomes: json['correct_outcomes'] as int? ?? 0,
    totalPoints: json['total_points'] as int? ?? 0,
    successRate: ((json['success_rate'] as num?) ?? 0).round(),
  );
}
