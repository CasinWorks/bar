import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/quest_system.dart';
import '../../providers/app_state.dart';

class CompetitiveLeaderboardPanel extends StatefulWidget {
  const CompetitiveLeaderboardPanel({super.key});

  @override
  State<CompetitiveLeaderboardPanel> createState() =>
      _CompetitiveLeaderboardPanelState();
}

class _CompetitiveLeaderboardPanelState
    extends State<CompetitiveLeaderboardPanel> {
  LeaderboardCategory _category = LeaderboardCategory.mostSocial;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rankings = state.competitiveRankings[_category] ?? [];

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: LeaderboardCategory.values.map((cat) {
              final selected = cat == _category;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 8,
                      color: selected
                          ? AppColors.matteBlack
                          : AppColors.textMuted,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.goldBright,
                  backgroundColor: AppColors.darkSteel,
                  onSelected: (_) => setState(() => _category = cat),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LuxuryCard(
                padding: const EdgeInsets.all(12),
                highlighted: true,
                child: Row(
                  children: [
                    Icon(_category.icon, color: AppColors.goldBright),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _category.label.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Tonight\'s competitive standings',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (rankings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No rankings yet — complete quests to climb!'),
                  ),
                )
              else
                ...rankings.map((r) => _RankingRow(ranking: r)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.ranking});
  final CompetitiveRanking ranking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LuxuryCard(
        highlighted: ranking.isCurrentUser,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(
              '#${ranking.rank}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ranking.isCurrentUser
                    ? AppColors.goldBright
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.goldBrushed.withValues(alpha: 0.25),
              child: Text(
                ranking.avatarGlyph,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ranking.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: ranking.isCurrentUser ? AppColors.goldBright : null,
                ),
              ),
            ),
            Text(
              '${ranking.score}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.timerNeon,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
