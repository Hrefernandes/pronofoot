import 'package:pronofoot/models/models.dart';
import 'package:pronofoot/repositories/repositories.dart';

/// Doublures en mémoire des repositories, pour piloter les écrans en test
/// via `ProviderScope(overrides: [...])` sans base de données.

Profile fakeProfile({String id = 'u1', String username = 'Tom'}) => Profile(
  id: id,
  username: username,
  avatarIcon: 'ball',
  avatarColor: '#FFB020',
  createdAt: DateTime.utc(2026, 3, 1),
);

Team fakeTeam({
  required String id,
  required String short,
  required String name,
}) => Team(
  id: id,
  leagueId: 'l1',
  shortName: short,
  name: name,
  colorPrimary: '#0B1220',
  colorSecondary: '#FFFFFF',
  colorText: '#FFFFFF',
);

League fakeLeague() => const League(
  id: 'l1',
  name: 'Ligue 1',
  country: 'France',
  colorPrimary: '#16203A',
  colorSecondary: '#1E2A47',
  colorText: '#F2F5FF',
);

MatchView fakeMatchView({
  String id = 'm1',
  MatchStatus status = MatchStatus.scheduled,
  DateTime? kickoff,
}) {
  return MatchView(
    match: Match(
      id: id,
      leagueId: 'l1',
      homeTeamId: 't1',
      awayTeamId: 't2',
      kickoffAt: kickoff ?? DateTime.now().add(const Duration(hours: 4)),
      status: status,
    ),
    homeTeam: fakeTeam(id: 't1', short: 'PSG', name: 'Paris Saint-Germain'),
    awayTeam: fakeTeam(id: 't2', short: 'OM', name: 'Olympique de Marseille'),
    league: fakeLeague(),
  );
}

Group fakeGroup({String id = 'g1', String name = 'Les Potos du Mardi'}) =>
    Group(
      id: id,
      name: name,
      inviteCode: 'K7XM2P',
      pointsExact: 3,
      pointsResult: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Membership fakeMembership({String groupId = 'g1'}) => Membership(
  member: GroupMember(
    id: 'gm1',
    groupId: groupId,
    profileId: 'u1',
    role: MemberRole.admin,
    totalPoints: 34,
    joinedAt: DateTime.utc(2026, 1, 2),
  ),
  group: fakeGroup(id: groupId),
  rank: 2,
  memberCount: 8,
);

// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.profile});

  Profile? profile;

  @override
  Stream<Profile?> authStateChanges() => Stream.value(profile);

  @override
  Profile? get currentProfile => profile;

  @override
  String? get currentUserId => profile?.id;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async => profile ??= fakeProfile();

  @override
  Future<Profile?> signUp({
    required String email,
    required String password,
    required String username,
  }) async => profile ??= fakeProfile(username: username);

  @override
  Future<void> signOut() async => profile = null;

  @override
  Future<Profile> updateUsername(String username) async {
    final current = profile ?? fakeProfile();
    return profile = Profile(
      id: current.id,
      username: username,
      avatarIcon: current.avatarIcon,
      avatarColor: current.avatarColor,
      createdAt: current.createdAt,
    );
  }

  @override
  Future<Profile> updateAvatar({
    required String avatarIcon,
    required String avatarColor,
  }) async {
    final current = profile ?? fakeProfile();
    return profile = Profile(
      id: current.id,
      username: current.username,
      avatarIcon: avatarIcon,
      avatarColor: avatarColor,
      createdAt: current.createdAt,
    );
  }
}

class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository(this._matches);

  final List<MatchView> _matches;

  @override
  Future<List<MatchView>> upcomingMatches() async => _matches;

  @override
  Future<MatchView> matchById(String matchId) async =>
      _matches.firstWhere((m) => m.id == matchId);
}

class RecordedPrediction {
  RecordedPrediction(this.matchId, this.homeScore, this.awayScore);

  final String matchId;
  final int homeScore;
  final int awayScore;
}

class FakePredictionRepository implements PredictionRepository {
  final List<RecordedPrediction> created = [];
  Prediction? existing;
  List<GroupPrediction> group = const [];

  @override
  Future<Map<String, Prediction>> myPredictions() async =>
      existing == null ? {} : {existing!.matchId: existing!};

  @override
  Future<Prediction?> myPrediction(String matchId) async => existing;

  @override
  Future<void> createPrediction({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    created.add(RecordedPrediction(matchId, homeScore, awayScore));
    existing = Prediction(
      id: 'p1',
      groupId: 'g1',
      profileId: 'u1',
      matchId: matchId,
      homeScorePred: homeScore,
      awayScorePred: awayScore,
      createdAt: DateTime.utc(2026, 3, 14),
    );
  }

  @override
  Future<List<GroupPrediction>> groupPredictions({
    required String groupId,
    required String matchId,
  }) async => group;

  List<RecentPrediction> recent = const [];

  @override
  Future<List<RecentPrediction>> myRecentPredictions({int limit = 10}) async =>
      recent;
}

class FakeGroupRepository implements GroupRepository {
  FakeGroupRepository({List<Membership>? memberships})
    : memberships = memberships ?? [fakeMembership()];

  final List<Membership> memberships;
  List<LeaderboardEntry> board = const [];
  List<PredictionHistoryEntry> history = const [];

  @override
  Future<List<Membership>> myGroups() async => memberships;

  @override
  Future<Group> groupById(String groupId) async =>
      memberships.firstWhere((m) => m.groupId == groupId).group;

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    int pointsExact = 3,
    int pointsResult = 1,
    String avatarIcon = 'ball',
    String avatarColor = '#FFB020',
  }) async => fakeGroup(name: name);

  @override
  Future<GroupSummary> findByCode(String code) async =>
      const GroupSummary(id: 'g9', name: 'Bureau', memberCount: 12);

  @override
  Future<Group> joinByCode(String code) async => fakeGroup(id: 'g9');

  @override
  Future<List<LeaderboardEntry>> leaderboard(String groupId) async => board;

  @override
  Future<List<PredictionHistoryEntry>> predictionHistory(
    String groupId,
  ) async => history;

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
  }) async => fakeGroup(id: groupId, name: name);

  @override
  Future<void> leaveGroup(String groupId) async {
    memberships.removeWhere((m) => m.groupId == groupId);
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String profileId,
  }) async {}
}

class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository([this.stats = MyStats.empty]);

  final MyStats stats;

  @override
  Future<MyStats> myStats() async => stats;
}
