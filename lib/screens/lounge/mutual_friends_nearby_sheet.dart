import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import 'friend_actions_sheet.dart';

class MutualFriendsNearbySheet extends StatefulWidget {
  const MutualFriendsNearbySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MutualFriendsNearbySheet(),
    );
  }

  @override
  State<MutualFriendsNearbySheet> createState() =>
      _MutualFriendsNearbySheetState();
}

class _MutualFriendsNearbySheetState extends State<MutualFriendsNearbySheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshMutualFriendsNearby();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LuxuryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mutual Friends Nearby',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Same branch only. Friends appear here only when both of you opted in.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 440),
                child: RefreshIndicator(
                  onRefresh: state.refreshMutualFriendsNearby,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (state.mutualFriendsNearby.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'No mutual friends nearby yet.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        ...state.mutualFriendsNearby.map(
                          (profile) => _NearbyFriendTile(profile: profile),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyFriendTile extends StatelessWidget {
  const _NearbyFriendTile({required this.profile});
  final FriendProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LuxuryCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        highlighted: true,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.timerNeon.withValues(alpha: 0.18),
              child: Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AppColors.timerNeon),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    profile.vibeTag ??
                        'Inside ${profile.branch ?? 'this branch'}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: AppColors.goldBright),
              onPressed: () => FriendActionsSheet.show(context, profile),
            ),
          ],
        ),
      ),
    );
  }
}
