import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/club_session.dart';
import '../../models/drink_order.dart';
import '../../providers/app_state.dart';

class DrinkDetailSheet extends StatefulWidget {
  const DrinkDetailSheet({super.key, required this.drink});

  final Drink drink;

  static Future<void> show(BuildContext context, Drink drink) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DrinkDetailSheet(drink: drink),
    );
  }

  @override
  State<DrinkDetailSheet> createState() => _DrinkDetailSheetState();
}

class _DrinkDetailSheetState extends State<DrinkDetailSheet> {
  bool _ordering = false;
  String? _error;

  Drink get drink => widget.drink;

  Future<void> _order({required bool payWithCash}) async {
    if (_ordering) return;
    final appState = context.read<AppState>();
    if (appState.isWalletBusy) {
      setState(() => _error = 'Hang on — another order is still processing.');
      return;
    }

    setState(() {
      _ordering = true;
      _error = null;
    });

    final inVipBefore = appState.isInVipRoom;

    final order = await appState.placeDrinkOrder(
      drink,
      payWithCash: payWithCash,
    );

    if (!mounted) return;

    if (order == null) {
      setState(() {
        _ordering = false;
        _error = payWithCash
            ? 'Could not place cash order. Try again.'
            : inVipBefore
            ? 'Not enough VIP room tab time — or order failed.'
            : 'Not enough time — or order failed. Try again.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _ordering = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payWithCash
              ? '${drink.name} sent to bar — pay when it arrives.'
              : '${drink.name} sent to bar — track it at the top.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final inside = state.sessionPhase == SessionPhase.insideClub;
    final inVip = state.isInVipRoom;
    final costSec = state.drinkOrderCostSeconds(drink);
    final chargeSource = state.chargeSourceForDrink(drink);
    final canAfford = state.canAffordDrink(drink);
    final canCash = inside;
    final blocked = _ordering || state.isWalletBusy;

    String primaryLabel;
    if (!inside) {
      primaryLabel = 'ENTER CLUB FIRST';
    } else if (inVip) {
      primaryLabel = canAfford
          ? 'SEND TO BAR (−${costSec ~/ 60} MIN · TAB)'
          : 'ROOM TAB EMPTY';
    } else if (!canAfford) {
      primaryLabel = 'NOT ENOUGH TIME';
    } else {
      primaryLabel = switch (chargeSource) {
        DrinkChargeSource.packageAllowance => 'SEND TO BAR (PACKAGE)',
        DrinkChargeSource.eventWallet =>
          'SEND TO BAR (−${costSec ~/ 60} MIN · EVENT)',
        DrinkChargeSource.personalTime =>
          'SEND TO BAR (−${costSec ~/ 60} MIN)',
        DrinkChargeSource.vipRoomTab =>
          'SEND TO BAR (−${costSec ~/ 60} MIN · TAB)',
        DrinkChargeSource.cashAtBar => 'SEND TO BAR (PAY AT BAR)',
      };
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Color(drink.imageColorStart),
                    Color(drink.imageColorEnd),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  drink.badge ?? drink.category.label.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (drink.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.goldBrushed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  drink.badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.goldBright,
                  ),
                ),
              ),
            Text(drink.name, style: Theme.of(context).textTheme.headlineMedium),
            Text(
              '${drink.flavor} • ${drink.abv}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.goldBright),
            ),
            const SizedBox(height: 12),
            Text(
              drink.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'INGREDIENTS',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 9),
            ),
            const SizedBox(height: 8),
            ...drink.ingredients.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.goldBrushed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LuxuryCard(
              child: Text(
                drink.bartenderQuote,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.goldBright,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  drink.price,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.tigerRed),
                ),
                Text(
                  switch (chargeSource) {
                    DrinkChargeSource.vipRoomTab =>
                      '−${costSec ~/ 60} min · VIP tab on serve',
                    DrinkChargeSource.eventWallet =>
                      '−${costSec ~/ 60} min · event wallet on serve',
                    DrinkChargeSource.packageAllowance =>
                      'Package drink · charged when served',
                    DrinkChargeSource.personalTime =>
                      '−${costSec ~/ 60} min · charged when served',
                    DrinkChargeSource.cashAtBar => 'Pay at the bar',
                  },
                  style: TextStyle(
                    color: switch (chargeSource) {
                      DrinkChargeSource.vipRoomTab => const Color(0xFF9B59B6),
                      DrinkChargeSource.eventWallet => AppColors.goldBright,
                      DrinkChargeSource.packageAllowance =>
                        AppColors.timerHealthy,
                      _ => AppColors.tigerRed,
                    },
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.tigerOrange,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TigerButton(
              label: primaryLabel,
              icon: Icons.local_bar,
              isLoading: _ordering,
              onPressed: (!blocked && canAfford)
                  ? () => _order(payWithCash: false)
                  : null,
            ),
            if (chargeSource != DrinkChargeSource.packageAllowance) ...[
              const SizedBox(height: 8),
              TigerButton(
                label: 'PAY AT BAR (CASH)',
                secondary: true,
                isLoading: _ordering,
                onPressed: (!blocked && canCash)
                    ? () => _order(payWithCash: true)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
