import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/group_avatar.dart';
import '../widgets/profile_avatar.dart';
import 'group_sheets.dart';

/// Onglets de l'écran E5.
enum _GroupTab { classement, palmares, historique }

/// E5 — Détail d'un groupe : classement, code d'invitation, barème,
/// historique des pronostics.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  _GroupTab _tab = _GroupTab.classement;
  bool _busyAction = false;

  bool _isAdmin(WidgetRef ref) {
    final memberships = ref.watch(myGroupsProvider).valueOrNull ?? const [];
    final mine = memberships.where((m) => m.groupId == widget.groupId);
    return mine.isNotEmpty && mine.first.role.isAdmin;
  }

  Future<void> _confirmLeave(Group group, bool isAdmin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.tribune,
        title: const Text('Quitter le groupe ?'),
        content: Text(
          isAdmin
              ? 'Tu es administrateur : le rôle sera transmis au membre le '
                    'plus ancien.'
              : 'Tu ne verras plus « ${group.name} » ni son classement.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alerte),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyAction = true);
    try {
      await ref.read(groupRepositoryProvider).leaveGroup(widget.groupId);
      if (!mounted) return;
      ref.invalidate(myGroupsProvider);
      Navigator.of(context).pop();
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmRemove(LeaderboardEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.tribune,
        title: const Text('Retirer ce membre ?'),
        content: Text(
          '${entry.username} ne fera plus partie du groupe.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alerte),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(groupRepositoryProvider)
          .removeMember(groupId: widget.groupId, profileId: entry.profileId);
      if (!mounted) return;
      ref.invalidate(leaderboardProvider(widget.groupId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.username} a été retiré du groupe.')),
      );
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final currentUserId = ref.watch(authRepositoryProvider).currentUserId;
    final isAdmin = _isAdmin(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text('GROUPE', style: AppText.eyebrow),
        actions: [
          if (isAdmin)
            groupAsync.maybeWhen(
              data: (group) => IconButton(
                tooltip: 'Paramètres du groupe',
                onPressed: () => showEditGroupSheet(context, group),
                icon: const Icon(Icons.tune),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: AsyncView(
        value: groupAsync,
        onRetry: () => ref.invalidate(groupProvider(widget.groupId)),
        data: (group) {
          final boardAsync = ref.watch(leaderboardProvider(widget.groupId));
          return RefreshIndicator(
            color: AppColors.or,
            onRefresh: () async {
              ref.invalidate(groupProvider(widget.groupId));
              ref.invalidate(leaderboardProvider(widget.groupId));
              await ref.read(leaderboardProvider(widget.groupId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenEdge,
                AppSpacing.s,
                AppSpacing.screenEdge,
                AppSpacing.xxl,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GroupAvatar(
                      icon: group.avatarIcon,
                      color: group.avatarColor,
                      size: 52,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        group.name.toUpperCase(),
                        style: AppText.screenTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  '${boardAsync.valueOrNull?.length ?? '—'} membres · '
                  'Score exact ${group.pointsExact} pts · '
                  'Bon résultat ${group.pointsResult} pt',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: AppSpacing.m),
                _InviteCodeCard(code: group.inviteCode),
                const SizedBox(height: AppSpacing.m),
                _Toggle(
                  tab: _tab,
                  showHistory: group.showPredictionHistory,
                  onChanged: (v) => setState(() => _tab = v),
                ),
                const SizedBox(height: AppSpacing.m),
                if (_tab == _GroupTab.historique && group.showPredictionHistory)
                  Consumer(
                    builder: (context, ref, _) {
                      final historyAsync = ref.watch(
                        predictionHistoryProvider(widget.groupId),
                      );
                      return AsyncView(
                        value: historyAsync,
                        onRetry: () => ref.invalidate(
                          predictionHistoryProvider(widget.groupId),
                        ),
                        data: (history) => _HistoryView(entries: history),
                      );
                    },
                  )
                else
                  AsyncView(
                    value: boardAsync,
                    onRetry: () =>
                        ref.invalidate(leaderboardProvider(widget.groupId)),
                    data: (board) => _tab == _GroupTab.classement
                        ? _Leaderboard(
                            board: board,
                            currentUserId: currentUserId,
                            isAdmin: isAdmin,
                            onRemove: _confirmRemove,
                          )
                        : _Palmares(board: board),
                  ),
                const SizedBox(height: AppSpacing.l),
                Center(
                  child: TextButton(
                    onPressed: _busyAction
                        ? null
                        : () => _confirmLeave(group, isAdmin),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.alerte,
                    ),
                    child: const Text('QUITTER LE GROUPE'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return DottedBorderBox(
      child: Column(
        children: [
          Text("CODE D'INVITATION", style: AppText.eyebrow),
          const SizedBox(height: AppSpacing.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code.split('').join(' '),
                style: AppText.mono.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.or,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Code copié.')),
                    );
                },
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                  color: AppColors.ardoise,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cadre à bordure pointillée (code d'invitation).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.m,
          horizontal: AppSpacing.m,
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.or.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const radius = 14.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.tab,
    required this.showHistory,
    required this.onChanged,
  });

  final _GroupTab tab;
  final bool showHistory;
  final ValueChanged<_GroupTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.tribune,
        borderRadius: AppRadii.allM,
        border: Border.all(color: AppColors.ligne),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: 'Classement',
            active: tab == _GroupTab.classement,
            onTap: () => onChanged(_GroupTab.classement),
          ),
          _ToggleTab(
            label: 'Palmarès',
            active: tab == _GroupTab.palmares,
            onTap: () => onChanged(_GroupTab.palmares),
          ),
          if (showHistory)
            _ToggleTab(
              label: 'Historique',
              active: tab == _GroupTab.historique,
              onTap: () => onChanged(_GroupTab.historique),
            ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.or : Colors.transparent,
            borderRadius: AppRadii.allS,
          ),
          child: Text(
            label,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? AppColors.surOr : AppColors.ardoise,
            ),
          ),
        ),
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({
    required this.board,
    required this.currentUserId,
    required this.isAdmin,
    required this.onRemove,
  });

  final List<LeaderboardEntry> board;
  final String? currentUserId;
  final bool isAdmin;
  final ValueChanged<LeaderboardEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) {
      return AppCard(
        child: Text(
          'Classement vide pour l\'instant.',
          style: AppText.bodyMuted,
        ),
      );
    }
    return Column(
      children: [
        for (final entry in board)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: _LeaderboardRow(
              entry: entry,
              isMe: entry.profileId == currentUserId,
              onRemove: (isAdmin && entry.profileId != currentUserId)
                  ? () => onRemove(entry)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    this.onRemove,
  });

  final LeaderboardEntry entry;
  final bool isMe;

  /// Non nul seulement pour un admin regardant un autre membre.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlight: isMe,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${entry.rank}',
              style: AppText.mono.copyWith(
                fontWeight: FontWeight.w700,
                color: entry.rank == 1 ? AppColors.or : AppColors.craie,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          ProfileAvatar(
            icon: entry.avatarIcon,
            color: entry.avatarColor,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isMe)
                      Text(
                        ' · toi',
                        style: AppText.bodyMuted.copyWith(color: AppColors.or),
                      ),
                  ],
                ),
                Text(
                  '${entry.exactScores} scores exacts',
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalPoints}',
            style: AppText.mono.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: entry.rank == 1 ? AppColors.or : AppColors.craie,
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Retirer du groupe',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 18,
                color: AppColors.alerte,
              ),
            ),
        ],
      ),
    );
  }
}

/// Vue « Palmarès » : mêmes membres, triés sur le nombre de scores exacts.
class _Palmares extends StatelessWidget {
  const _Palmares({required this.board});

  final List<LeaderboardEntry> board;

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) {
      return AppCard(
        child: Text(
          'Rien à afficher pour l\'instant.',
          style: AppText.bodyMuted,
        ),
      );
    }
    final sorted = [...board]
      ..sort((a, b) => b.exactScores.compareTo(a.exactScores));
    return Column(
      children: [
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    icon: entry.avatarIcon,
                    color: entry.avatarColor,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.username,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${entry.exactScores}',
                    style: AppText.mono.copyWith(
                      color: AppColors.exact,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(' exacts', style: AppText.bodyMuted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Historique des pronostics notés, groupé par membre — un volet dépliable
/// par personne (E5, activable/désactivable par l'admin).
class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.entries});

  final List<PredictionHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppCard(
        child: Text(
          'Aucun match noté pour l\'instant.',
          style: AppText.bodyMuted,
        ),
      );
    }
    // Regroupe par membre en conservant l'ordre d'apparition (le repository
    // trie déjà par date décroissante).
    final byMember = <String, List<PredictionHistoryEntry>>{};
    final order = <String>[];
    for (final entry in entries) {
      if (!byMember.containsKey(entry.profileId)) order.add(entry.profileId);
      byMember.putIfAbsent(entry.profileId, () => []).add(entry);
    }
    return Column(
      children: [
        for (final profileId in order)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: _MemberHistoryTile(entries: byMember[profileId]!),
          ),
      ],
    );
  }
}

class _MemberHistoryTile extends StatelessWidget {
  const _MemberHistoryTile({required this.entries});

  final List<PredictionHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    final totalPoints = entries.fold<int>(0, (sum, e) => sum + e.pointsEarned);
    return Material(
      color: AppColors.tribune,
      borderRadius: AppRadii.allL,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.allL),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: AppRadii.allL,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          iconColor: AppColors.ardoise,
          collapsedIconColor: AppColors.ardoise,
          leading: ProfileAvatar(
            icon: first.avatarIcon,
            color: first.avatarColor,
            size: 32,
          ),
          title: Text(
            first.username,
            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${entries.length} pronostic${entries.length > 1 ? 's' : ''} noté'
            '${entries.length > 1 ? 's' : ''}',
            style: AppText.bodyMuted,
          ),
          trailing: Text(
            '$totalPoints pts',
            style: AppText.mono.copyWith(
              color: AppColors.or,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [for (final entry in entries) _HistoryRow(entry: entry)],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final PredictionHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final exact =
        entry.predHome == entry.actualHomeScore &&
        entry.predAway == entry.actualAwayScore;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        0,
        AppSpacing.m,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${entry.homeTeamShort} ${entry.actualHomeScore}-'
              '${entry.actualAwayScore} ${entry.awayTeamShort}',
              style: AppText.bodyMuted,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.predHome}-${entry.predAway}',
            style: AppText.mono.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '+${entry.pointsEarned}',
            style: AppText.mono.copyWith(
              fontWeight: FontWeight.w700,
              color: exact
                  ? AppColors.exact
                  : entry.pointsEarned > 0
                  ? AppColors.or
                  : AppColors.ardoise,
            ),
          ),
        ],
      ),
    );
  }
}
