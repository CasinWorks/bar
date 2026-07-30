import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/tiger_motion.dart';
import '../../models/quest_system.dart';
import '../../providers/app_state.dart';

class QuestsPanel extends StatelessWidget {
  const QuestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mystery = state.mysteryQuest;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mystery != null) ...[
          FadeSlideIn(
            child: LuxuryCard(
              highlighted: true,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_off,
                        color: AppColors.tigerRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'YOUR SECRET MISSION',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mystery.objective,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only you can see this · Complete before exit',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 9),
                  ),
                  if (mystery.isComplete && !mystery.claimed) ...[
                    const SizedBox(height: 10),
                    TigerButton(
                      label: 'CLAIM MYSTERY REWARD',
                      onPressed: () => state.claimQuest(mystery.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final category in QuestCategory.values)
          if (_questsFor(state, category).isNotEmpty) ...[
            FadeSlideIn(child: _CategoryHeader(category: category)),
            const SizedBox(height: 6),
            ..._questsFor(state, category).map(
              (q) => FadeSlideIn(
                child: _QuestCard(
                  quest: q,
                  onProgress: () => state.progressQuest(q.id),
                  onClaim: () => state.claimQuest(q.id),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  static List<ClubQuest> _questsFor(AppState state, QuestCategory category) {
    return state.activeQuests.where((q) => q.category == category).toList();
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});
  final QuestCategory category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(category.icon, size: 14, color: AppColors.goldBright),
        const SizedBox(width: 6),
        Text(
          category.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
        ),
        const Spacer(),
        Text(
          category.difficulty,
          style: const TextStyle(fontSize: 7, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.onProgress,
    required this.onClaim,
  });

  final ClubQuest quest;
  final VoidCallback onProgress;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LuxuryCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quest.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (quest.movieTheme != null)
                  Text(
                    quest.movieTheme!,
                    style: const TextStyle(
                      fontSize: 7,
                      color: AppColors.goldBrushed,
                    ),
                  ),
              ],
            ),
            Text(
              quest.objective,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: quest.progress,
                minHeight: 5,
                color: AppColors.goldBrushed,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${quest.currentCount}/${quest.targetCount}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                ...quest.rewards.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      r.displayLabel,
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.tigerRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (quest.isComplete && !quest.claimed)
              TigerButton(label: 'CLAIM', onPressed: onClaim)
            else if (!quest.isComplete &&
                quest.category != QuestCategory.reputation)
              TigerButton(
                label: 'LOG PROGRESS',
                secondary: true,
                onPressed: onProgress,
              )
            else if (quest.claimed)
              const Text(
                'CLAIMED',
                style: TextStyle(
                  color: AppColors.successGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReputationPanel extends StatelessWidget {
  const ReputationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final level = state.reputationLevel;
    final xp = state.reputationXp;
    final next = level.next;
    final progress = next == null
        ? 1.0
        : ((xp - level.xpRequired) / (next.xpRequired - level.xpRequired))
              .clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: LuxuryCard(
            highlighted: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.pets, color: AppColors.goldBright, size: 36),
                const SizedBox(height: 8),
                Text(
                  level.label.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.goldBright,
                  ),
                ),
                Text(
                  '$xp reputation XP',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: AppColors.goldBrushed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${next.xpRequired - xp} XP to ${next.label}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: Text(
            'RANK UNLOCKS',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        ...level.unlocks.map(
          (u) => FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_open,
                    size: 12,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(u, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: Text(
            'REPUTATION PATH',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        ...ReputationLevel.values.map(
          (l) => FadeSlideIn(
            child: _RankStep(level: l, current: level, xp: xp),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: Text(
            'REPUTATION QUESTS',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 8),
        ...state.activeQuests
            .where((q) => q.category == QuestCategory.reputation)
            .map(
              (q) => FadeSlideIn(
                child: _QuestCard(
                  quest: q,
                  onProgress: () {},
                  onClaim: () => state.claimQuest(q.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _RankStep extends StatelessWidget {
  const _RankStep({
    required this.level,
    required this.current,
    required this.xp,
  });

  final ReputationLevel level;
  final ReputationLevel current;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final reached = xp >= level.xpRequired;
    final isCurrent = level == current;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LuxuryCard(
        highlighted: isCurrent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              reached ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: reached ? AppColors.successGreen : AppColors.neutral500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isCurrent ? AppColors.goldBright : null,
                    ),
                  ),
                  Text(
                    '${level.xpRequired} XP',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
