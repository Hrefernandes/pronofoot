import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/group_avatar.dart';
import 'group_detail_screen.dart';
import 'group_sheets.dart';

/// E4 — Mes groupes + créer / rejoindre.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);

    return RefreshIndicator(
      color: AppColors.or,
      onRefresh: () async {
        ref.invalidate(myGroupsProvider);
        await ref.read(myGroupsProvider.future);
      },
      child: AsyncView(
        value: groupsAsync,
        onRetry: () => ref.invalidate(myGroupsProvider),
        data: (memberships) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdge,
            AppSpacing.m,
            AppSpacing.screenEdge,
            AppSpacing.xxl,
          ),
          children: [
            ScreenTitle(
              'Mes groupes',
              subtitle: memberships.isEmpty
                  ? 'Aucun groupe pour l\'instant'
                  : '${memberships.length} groupe'
                        '${memberships.length > 1 ? 's' : ''} actif'
                        '${memberships.length > 1 ? 's' : ''}',
            ),
            const SizedBox(height: AppSpacing.l),
            for (final membership in memberships) ...[
              _GroupTile(membership: membership),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.s),
            ElevatedButton(
              onPressed: () => showCreateGroupSheet(context, ref),
              child: const Text('CRÉER UN GROUPE'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => showJoinGroupSheet(context, ref),
              child: const Text('REJOINDRE AVEC UN CODE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final group = membership.group;
    return AppCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GroupDetailScreen(groupId: group.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GroupAvatar(
                icon: group.avatarIcon,
                color: group.avatarColor,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(group.name, style: AppText.cardTitle)),
              if (membership.role.isAdmin)
                Text(
                  'ADMIN',
                  style: AppText.eyebrow.copyWith(color: AppColors.or),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${membership.memberCount} membres · ${group.scoringLabel}',
            style: AppText.bodyMuted,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(),
          ),
          Row(
            children: [
              Text('Ma place ', style: AppText.bodyMuted),
              Text(
                '${membership.rank}ᵉ',
                style: AppText.mono.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(' / ${membership.memberCount}', style: AppText.bodyMuted),
              const Spacer(),
              Text(
                '${membership.totalPoints}',
                style: AppText.mono.copyWith(
                  color: AppColors.or,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(' pts', style: AppText.bodyMuted),
            ],
          ),
        ],
      ),
    );
  }
}
