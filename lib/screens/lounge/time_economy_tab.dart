import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/tiger_motion.dart';
import '../../models/time_economy.dart';
import '../../providers/app_state.dart';
import 'night_event_sheet.dart';
import 'quests_panel.dart';
import 'time_wallet_display.dart';

/// Real-time economy transparency strip — club state, decay, buffs.
class TimeEconomyStatsBar extends StatelessWidget {
  const TimeEconomyStatsBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<AppState>().timeEconomySnapshot;
    final club = snapshot.clubState;

    if (compact) {
      return Row(
        children: [
          _Chip(
            label: club.label.toUpperCase(),
            color: _windowColor(club.window),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: '×${snapshot.flowMultiplier.toStringAsFixed(1)}',
            color: AppColors.goldBright,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              snapshot.decayRateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    return LuxuryCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 14, color: _windowColor(club.window)),
              const SizedBox(width: 6),
              Text(
                'TIME ECONOMY',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 8),
              ),
              const Spacer(),
              Text(
                '${club.occupancyPercent}% FULL',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: _windowColor(club.window),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'CLUB STATE',
                  value: club.label,
                  sub: club.clubState,
                ),
              ),
              Expanded(
                child: _StatCell(
                  label: 'FLOW',
                  value: '×${snapshot.flowMultiplier.toStringAsFixed(1)}',
                  sub: 'Event multiplier',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'DECAY',
                  value: snapshot.decayRateLabel,
                  sub: '${snapshot.minutesRemaining} min left',
                ),
              ),
            ],
          ),
          if (snapshot.activeBuffs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: snapshot.activeBuffs.map((b) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.successGreen.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    b.type.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static Color _windowColor(ClubTimeWindow window) => switch (window) {
    ClubTimeWindow.opening => AppColors.timerHealthy,
    ClubTimeWindow.peak => AppColors.goldBright,
    ClubTimeWindow.frenzy => AppColors.tigerRed,
    ClubTimeWindow.lastCall => AppColors.dangerRed,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 7),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.offWhite,
          ),
        ),
        Text(
          sub,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 8),
        ),
      ],
    );
  }
}

/// Hub: Economy · Quests · Reputation
class TimeEconomyTab extends StatelessWidget {
  const TimeEconomyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.goldBright,
            unselectedLabelColor: AppColors.neutral500,
            indicatorColor: AppColors.tigerRed,
            labelStyle: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
            tabs: const [
              Tab(text: 'ECONOMY'),
              Tab(text: 'QUESTS'),
              Tab(text: 'REP'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [_EconomyPanel(), QuestsPanel(), ReputationPanel()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EconomyPanel extends StatelessWidget {
  const _EconomyPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final snapshot = state.timeEconomySnapshot;
    final tier = state.playerVisitTier;
    final visits = state.lifetimeVisits;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: LuxuryCard(
            padding: const EdgeInsets.all(12),
            child: TimeWalletDisplay(snapshot: state.timeWallet),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 20),
          child: const LuxuryCard(
            padding: EdgeInsets.all(12),
            child: TimeEconomyRulesCard(),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 30),
          child: const TimeEconomyStatsBar(),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 40),
          child: LuxuryCard(
            padding: const EdgeInsets.all(12),
            highlighted: true,
            child: Row(
              children: [
                const Icon(Icons.military_tech, color: AppColors.goldBright),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.label.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: AppColors.goldBright,
                        ),
                      ),
                      Text(
                        '$visits visits · ${state.points} XP tonight',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (tier != PlayerVisitTier.legend)
                  Text(
                    _EconomyPanel.nextTierLabel(tier, visits),
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Text(
            'TONIGHT\'S TIMELINE',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        ...state.nightTimeline.asMap().entries.map(
          (e) => FadeSlideIn(
            delay: Duration(milliseconds: 100 + e.key * 40),
            child: _TimelineTile(
              event: e.value,
              onTap: e.value.isActive
                  ? () => NightEventSheet.show(context, e.value)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 300),
          child: Text(
            'ACHIEVEMENTS',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        ...state.achievementBadges.map(
          (badge) => FadeSlideIn(
            delay: const Duration(milliseconds: 320),
            child: _BadgeTile(badge: badge),
          ),
        ),
        if (snapshot.nextEvent != null) ...[
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 360),
            child: TigerButton(
              label: snapshot.nextEvent!.isActive
                  ? 'JOIN ${snapshot.nextEvent!.title.toUpperCase()}'
                  : 'NEXT: ${snapshot.nextEvent!.title.toUpperCase()}',
              icon: snapshot.nextEvent!.icon,
              onPressed: snapshot.nextEvent!.isActive
                  ? () => NightEventSheet.show(context, snapshot.nextEvent!)
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  static String nextTierLabel(PlayerVisitTier tier, int visits) {
    final next = switch (tier) {
      PlayerVisitTier.firstTimer => PlayerVisitTier.regular,
      PlayerVisitTier.regular => PlayerVisitTier.insider,
      PlayerVisitTier.insider => PlayerVisitTier.vipTiger,
      PlayerVisitTier.vipTiger => PlayerVisitTier.legend,
      PlayerVisitTier.legend => PlayerVisitTier.legend,
    };
    final needed = next.visitsRequired - visits;
    if (needed <= 0) return '';
    return '$needed to ${next.label}';
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, this.onTap});
  final NightTimelineEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = event.isActive;
    final done = event.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: LuxuryCard(
            highlighted: active,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.tigerRed.withValues(alpha: 0.2)
                        : AppColors.darkSteel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    event.icon,
                    size: 18,
                    color: done
                        ? AppColors.successGreen
                        : active
                        ? AppColors.tigerRed
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            event.triggerLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.goldBrushed,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: done
                                    ? AppColors.successGreen
                                    : AppColors.offWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        event.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 9),
                      ),
                      if (done && event.rewardMinutes > 0)
                        Text(
                          '+${event.rewardMinutes} min earned',
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.timerHealthy,
                          ),
                        ),
                    ],
                  ),
                ),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tigerRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: AppColors.tigerRed,
                      ),
                    ),
                  )
                else if (done)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.successGreen,
                    size: 16,
                  )
                else
                  const Icon(
                    Icons.schedule,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: badge.unlocked ? 1 : 0.45,
        child: LuxuryCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                badge.icon,
                color: badge.unlocked
                    ? AppColors.goldBright
                    : AppColors.neutral500,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: badge.unlocked
                            ? AppColors.goldBright
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      badge.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              if (badge.unlocked)
                const Icon(
                  Icons.verified,
                  color: AppColors.successGreen,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
