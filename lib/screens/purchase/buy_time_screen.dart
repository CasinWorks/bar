import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../data/mock_data.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';

class BuyTimeScreen extends StatefulWidget {
  const BuyTimeScreen({super.key});

  @override
  State<BuyTimeScreen> createState() => _BuyTimeScreenState();
}

class _BuyTimeScreenState extends State<BuyTimeScreen> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final inClub = state.sessionPhase == SessionPhase.insideClub;
    final selectedMinutes = state.selectedTimeMinutes;
    final selectedPrice = AppTimePricing.discountedPriceForMinutes(selectedMinutes);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Buy Time'),
      ),
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUY CLUB TIME',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 20),
                ),
                Text(
                  inClub
                      ? 'Purchased time is added to your active pass immediately. It stays on your account if you sign out.'
                      : 'Purchased time is saved to your account wallet. Use it on your next visit.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _BalanceCard(state: state, inClub: inClub),
                const SizedBox(height: 16),
                Text(
                  'SELECT PACKAGE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      ...MockData.timePackages.map((pkg) {
                        final selected = state.selectedTimePackageId == pkg.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PackageCard(
                            package: pkg,
                            selected: selected,
                            onTap: () {
                              state.selectTimePackage(pkg);
                              _customController.clear();
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Text(
                        'CUSTOM AMOUNT',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter minutes (e.g. 45)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value.trim());
                          if (parsed != null && parsed > 0) {
                            state.setSelectedTimeMinutes(parsed);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                LuxuryCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total:', style: Theme.of(context).textTheme.bodyMedium),
                          Text(
                            '₱$selectedPrice • ${selectedMinutes}m',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.goldBright,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                        label: 'SECURE PURCHASE',
                        icon: Icons.shield,
                        onPressed: selectedMinutes < 1
                            ? null
                            : () => context.push('/buy-time/checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.state, required this.inClub});

  final AppState state;
  final bool inClub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.timerNeon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.timerNeon.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inClub) ...[
            Text(
              'ACTIVE PASS: ${state.formatDuration(state.timeRemaining)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.timerNeon,
                    fontWeight: FontWeight.w900,
                    shadows: AppColors.timerGlow(AppColors.timerNeon, intensity: 0.55),
                  ),
            ),
            if (state.timeBalance > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Saved wallet: ${state.formatDuration(state.timeBalance)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10,
                      color: AppColors.timerNeonGlow,
                    ),
              ),
            ],
          ] else ...[
            Text(
              'SAVED TIME: ${state.formatDuration(state.timeBalance)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.timerNeon,
                    fontWeight: FontWeight.w900,
                    shadows: AppColors.timerGlow(AppColors.timerNeon, intensity: 0.55),
                  ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Time never expires — it stays on your account until you spend it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final TimePackage package;
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
                  if (package.popular)
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
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Text(
                    package.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    package.tagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${package.price}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10,
                      ),
                ),
                Text(
                  '₱${package.discountedPrice}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w900,
                      ),
                ),
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
