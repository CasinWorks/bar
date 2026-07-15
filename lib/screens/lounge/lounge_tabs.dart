import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/tiger_motion.dart';
import '../../data/mock_data.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import 'drink_detail_sheet.dart';
import 'mini_game_modal.dart';
import 'pass_the_glass_sheet.dart';
import 'toast_to_meet_sheet.dart';

class ChallengesTab extends StatelessWidget {
  const ChallengesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('SOCIALITE CHALLENGES', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9)),
        const SizedBox(height: 8),
        ...state.challenges.map((chal) => _ChallengeCard(challenge: chal)),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final progress = (challenge.currentCount / challenge.targetCount).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LuxuryCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(challenge.icon), color: AppColors.goldBright, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('+${challenge.points} PTS', style: const TextStyle(color: AppColors.goldBright, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, color: AppColors.goldBrushed),
            ),
            const SizedBox(height: 4),
            Text(
              '${challenge.currentCount}/${challenge.targetCount}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
            ),
            if (challenge.isComplete && !challenge.claimed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TigerButton(
                  label: 'CLAIM REWARD',
                  onPressed: () => state.claimChallenge(challenge.id),
                ),
              ),
            if (challenge.claimed)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('CLAIMED', style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String icon) => switch (icon) {
        'door' => Icons.door_front_door,
        'drink' => Icons.local_bar,
        'game' => Icons.casino,
        'social' => Icons.people,
        _ => Icons.star,
      };
}

class GamesTab extends StatefulWidget {
  const GamesTab({super.key});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshWhosInside();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final others = state.whosInside.where((p) => !p.isSelf).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: Text(
            'WITH SOMEONE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: LuxuryCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open to Meet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          state.canSpendTime
                              ? 'Appear on Who’s Inside at this branch'
                              : 'Enter the club with time to opt in',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.openToMeet,
                    activeThumbColor: AppColors.timerNeon,
                    onChanged: state.canSpendTime
                        ? (v) => state.setOpenToMeet(v)
                        : null,
                  ),
                ],
              ),
              if (state.openToMeet || state.canSpendTime) ...[
                const SizedBox(height: 10),
                Text(
                  'YOUR VIBE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 8),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: SocialVibeTags.options.map((tag) {
                    final selected = state.vibeTag == tag;
                    return GestureDetector(
                      onTap: () => state.setVibeTag(tag),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected ? AppColors.goldBright : AppColors.neutral500,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: selected
                              ? AppColors.goldBright.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? AppColors.goldBright : AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: Text(
            'WHO’S INSIDE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        if (others.isEmpty)
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: LuxuryCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                state.openToMeet
                    ? 'You’re visible — waiting for other socialites…'
                    : 'Turn on Open to Meet to see who’s down for a toast.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
            ),
          )
        else
          ...others.asMap().entries.map(
                (e) => FadeSlideIn(
                  delay: Duration(milliseconds: 120 + e.key * 50),
                  child: _PresenceTile(presence: e.value),
                ),
              ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: TigerButton(
            label: 'TOAST TO MEET',
            icon: Icons.qr_code_2,
            onPressed: state.canSpendTime
                ? () => ToastToMeetSheet.show(context)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 220),
          child: TigerButton(
            label: 'DUO BEAT SYNC',
            icon: Icons.music_note,
            onPressed: state.canSpendTime
                ? () => DuoBeatSheet.show(context)
                : null,
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          delay: const Duration(milliseconds: 260),
          child: Text(
            'SOLO',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 300),
          child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: MockData.miniGames.length,
          itemBuilder: (context, i) {
            final game = MockData.miniGames[i];
            final locked = (game.locked && state.points < 150) || !state.canSpendTime;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: locked
                    ? null
                    : () {
                        if (!state.canSpendTime) return;
                        MiniGameModal.show(context, game);
                      },
                child: Opacity(
                  opacity: locked ? 0.5 : 1,
                  child: LuxuryCard(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _gameIcon(game.icon),
                          color: locked ? AppColors.neutral500 : AppColors.goldBright,
                        ),
                        const Spacer(),
                        Text(
                          game.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          '+${game.points} PTS',
                          style: const TextStyle(fontSize: 9, color: AppColors.goldBrushed),
                        ),
                        if (locked)
                          Text(
                            game.lockRequirement ?? '',
                            style: const TextStyle(fontSize: 8, color: AppColors.tigerOrange),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ),
      ],
    );
  }

  IconData _gameIcon(String icon) => switch (icon) {
        'roulette' => Icons.album,
        'guess' => Icons.psychology,
        'shot' => Icons.music_note,
        'card' => Icons.style,
        'cipher' => Icons.lock,
        'mystery' => Icons.workspace_premium,
        _ => Icons.videogame_asset,
      };
}

class _PresenceTile extends StatelessWidget {
  const _PresenceTile({required this.presence});
  final SocialPresence presence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LuxuryCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.goldBrushed.withValues(alpha: 0.25),
              child: Text(
                presence.displayName.isNotEmpty
                    ? presence.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presence.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    presence.vibeTag,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.waving_hand, size: 16, color: AppColors.timerNeon),
          ],
        ),
      ),
    );
  }
}

class SocialTab extends StatelessWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TigerButton(
          label: 'PASS THE GLASS',
          icon: Icons.local_bar,
          onPressed: () => PassTheGlassSheet.show(context),
        ),
        const SizedBox(height: 12),
        Text('LOUNGE ACTIVITY', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9)),
        const SizedBox(height: 8),
        ...state.feedEvents.map((event) => _FeedCard(event: event)),
      ],
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.event});
  final FeedEvent event;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LuxuryCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(event.avatarSeed.color),
                  child: Text(event.avatarSeed.hair, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${event.userName} ${event.userRank}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      Text(event.timeAgo, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.eventText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              children: [
                _ReactionBtn(label: 'LUXE', count: event.likes['luxe'] ?? 0, active: event.userReacted == 'luxe', onTap: () => state.reactToFeed(event.id, 'luxe')),
                _ReactionBtn(label: 'SALUTE', count: event.likes['salute'] ?? 0, active: event.userReacted == 'salute', onTap: () => state.reactToFeed(event.id, 'salute')),
                _ReactionBtn(label: 'GOLD', count: event.likes['gold'] ?? 0, active: event.userReacted == 'gold', onTap: () => state.reactToFeed(event.id, 'gold')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBtn extends StatelessWidget {
  const _ReactionBtn({required this.label, required this.count, required this.active, required this.onTap});
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: active ? AppColors.goldBright : AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text('$label $count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class MenuTab extends StatelessWidget {
  const MenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('STORYTELLING CONCOCTIONS', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9)),
        const SizedBox(height: 8),
        ...MockData.drinks.map((drink) => _DrinkTile(drink: drink)),
      ],
    );
  }
}

class _DrinkTile extends StatelessWidget {
  const _DrinkTile({required this.drink});
  final Drink drink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => DrinkDetailSheet.show(context, drink),
          child: LuxuryCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(colors: [Color(drink.imageColorStart), Color(drink.imageColorEnd)]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drink.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(drink.flavor, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 9)),
                      Text('-${drink.timeCostSeconds ~/ 60} min', style: const TextStyle(color: AppColors.dangerRed, fontSize: 9)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(drink.price, style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold, fontSize: 11)),
                    const Icon(Icons.chevron_right, color: AppColors.goldBrushed, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      color: AppColors.goldBrushed,
      backgroundColor: AppColors.cardSurface,
      onRefresh: () => context.read<AppState>().refreshLeaderboard(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          LuxuryCard(
            padding: const EdgeInsets.all(12),
            highlighted: true,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(state.avatar.color),
                  child: Text(
                    state.avatar.name.isNotEmpty
                        ? state.avatar.name.substring(0, 1)
                        : 'Y',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.user?.name ?? 'You', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '#${state.currentRank} • ${state.formatDuration(state.spendableTimeSeconds)} • ${state.memberTier.label}',
                        style: const TextStyle(color: AppColors.timerNeon, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  '#${state.currentRank}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: AppColors.goldBright,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'LIVE CLUB RANKINGS · BY WALLET TIME',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
          const SizedBox(height: 8),
          if (state.leaderboard.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Pull to refresh rankings…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...state.leaderboard.map((user) => _LeaderRow(user: user)),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.user});
  final LeaderboardUser user;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final timeLabel = state.formatDuration(user.timeBalance ?? 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LuxuryCard(
        highlighted: user.isCurrentUser,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text('#${user.rank}', style: TextStyle(color: user.isCurrentUser ? AppColors.goldBright : AppColors.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(user.avatarColor),
              child: Text(user.avatarGlyph, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: user.isCurrentUser ? AppColors.goldBright : null)),
                  Text(user.tier.label, style: TextStyle(fontSize: 9, color: user.tier.accentColor)),
                ],
              ),
            ),
            Text(
              timeLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: user.isCurrentUser ? AppColors.timerNeon : AppColors.timerNeonGlow,
                fontSize: 11,
                shadows: user.isCurrentUser
                    ? AppColors.timerGlow(AppColors.timerNeon, intensity: 0.5)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
