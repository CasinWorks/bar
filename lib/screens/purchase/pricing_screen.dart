import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../data/mock_data.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';
import '../lounge/pass_the_glass_sheet.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final extendingPass = state.sessionPhase == SessionPhase.insideClub;
    final showPassPurchase = state.canPurchaseNewPass;
    final hasWallet = state.timeBalance > 0;
    final loadLabel = state.formatDuration(state.totalLoadSeconds);

    return Scaffold(
      appBar: extendingPass
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/lounge'),
              ),
              title: const Text('Load Time'),
            )
          : null,
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showPassPurchase
                      ? (extendingPass ? 'LOAD MORE HOURS' : 'REDEEM SOCIALITE PASS')
                      : 'YOUR CLUB TIME',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 20),
                ),
                Text(
                  showPassPurchase
                      ? (extendingPass
                          ? 'Your pass stays active. Ask the house to load more hours.'
                          : 'Redeem club hours loaded by the house, or use your wallet balance.')
                      : 'You still have $loadLabel on your account. Use your balance — new loads are done at the club.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (state.hasActiveLoad) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.timerNeon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.timerNeon.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'TOTAL LOAD: $loadLabel',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.timerNeon,
                                fontWeight: FontWeight.w900,
                                shadows: AppColors.timerGlow(AppColors.timerNeon, intensity: 0.55),
                              ),
                        ),
                        if (hasWallet) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Saved wallet: ${state.formatDuration(state.timeBalance)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 10,
                                  color: AppColors.timerNeonGlow,
                                ),
                          ),
                        ],
                        if (extendingPass) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Active pass: ${state.formatDuration(state.timeRemaining)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 10,
                                  color: AppColors.timerNeonGlow,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                LuxuryCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Time loads are temporarily in-club only — see the house / admin desk.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                TigerButton(
                  label: 'PASS THE GLASS',
                  icon: Icons.local_bar,
                  secondary: true,
                  onPressed: () => PassTheGlassSheet.show(context),
                ),
                if (!extendingPass && hasWallet) ...[
                  const SizedBox(height: 12),
                  TigerButton(
                    label: 'USE MY TIME BALANCE',
                    icon: Icons.account_balance_wallet,
                    secondary: true,
                    onPressed: () async {
                      final ok = await state.startVisitWithTimeBalance();
                      if (!context.mounted) return;
                      if (ok) context.go('/entry');
                    },
                  ),
                ],
                if (!showPassPurchase) ...[
                  const Spacer(),
                  Text(
                    'Socialite pass tiers appear when your load drops below 5 minutes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (showPassPurchase) ...[
                  const SizedBox(height: 16),
                  Text(
                    'SELECT BRANCH',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MockData.clubBranches.map((branch) {
                      final selected = state.selectedBranch == branch.name;
                      return ChoiceChip(
                        label: Text(branch.name),
                        selected: selected,
                        onSelected: (_) => state.setSelectedBranch(branch.name),
                        selectedColor: AppColors.goldBrushed.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                          fontSize: 10,
                          color: selected ? AppColors.goldBright : AppColors.neutral400,
                        ),
                      );
                    }).toList(),
                  ),
                  const Spacer(),
                  LuxuryCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.storefront, color: AppColors.goldBright, size: 32),
                        const SizedBox(height: 10),
                        Text(
                          'IN-CLUB TIME LOADS ONLY',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.goldBright,
                                fontWeight: FontWeight.w900,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask the house or admin desk to load minutes to your account, then use your time balance to enter.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _TierCard (in-app pass purchase UI) temporarily removed — restore with Buy Time.

