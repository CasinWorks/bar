import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../data/mock_data.dart';
import '../../models/blind_tiger_models.dart';
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
                          ? 'Time is currency — your pass stays active. Add hours to continue your evening.'
                          : 'Buy club hours to spend inside. Your pass stays active until time runs out.')
                      : 'You still have $loadLabel on your account. Use your balance or buy more time — a new pass unlocks under 5 minutes.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (state.hasActiveLoad) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'TOTAL LOAD: $loadLabel',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        if (hasWallet) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Saved wallet: ${state.formatDuration(state.timeBalance)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                          ),
                        ],
                        if (extendingPass) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Active pass: ${state.formatDuration(state.timeRemaining)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TigerButton(
                  label: 'BUY TIME',
                  icon: Icons.bolt,
                  onPressed: () => context.push('/buy-time'),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.goldBrushed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.goldBrushed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people, color: AppColors.goldBright, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'GCash Referral Active',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.goldBright,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.goldBrushed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '15% OFF',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: MockData.priceTiers.map((tier) {
                        final selected = state.selectedTier.id == tier.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TierCard(
                            tier: tier,
                            selected: selected,
                            onTap: () => state.setSelectedTier(tier),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  LuxuryCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Charged:', style: Theme.of(context).textTheme.bodyMedium),
                            Text(
                              '₱${state.selectedTier.discountedPrice} • ${state.selectedTier.duration}m Club Pass',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.goldBright,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'PAYMENT METHOD',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 8,
                                letterSpacing: 1,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: PaymentMethod.values.map((method) {
                            final selected = state.paymentMethod == method;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: GestureDetector(
                                  onTap: () => state.setPaymentMethod(method),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.goldBrushed
                                            : AppColors.neutral900,
                                      ),
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.transparent,
                                    ),
                                    child: Text(
                                      method.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: selected ? AppColors.goldBright : AppColors.neutral400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        TigerButton(
                          label: extendingPass ? 'ADD HOURS TO PASS' : 'SECURE TRANSACTION',
                          icon: Icons.shield,
                          onPressed: () => context.go('/checkout'),
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

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final PriceTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LuxuryCard(
        highlighted: selected,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tier.popular)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.tigerOrange, AppColors.goldBrushed],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RECOMMENDED',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${tier.duration}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'MINUTES',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  Text(
                    tier.tagline,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                  ),
                  Text(
                    tier.valueProp,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${tier.price}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10,
                      ),
                ),
                Text(
                  '₱${tier.discountedPrice}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.goldBrushed : AppColors.neutral500,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
