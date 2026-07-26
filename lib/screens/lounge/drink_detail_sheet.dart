import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/time_refill_overlay.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/club_session.dart';
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

    final beforeSeconds = appState.spendableTimeSeconds;
    final beforeDrinks = appState.drinksAllowanceRemaining;
    final ok = await appState.orderDrink(drink, payWithCash: payWithCash);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _ordering = false;
        _error = payWithCash
            ? 'Could not place cash order. Try again.'
            : drink.isStandard
                ? 'No package drinks left — or order failed.'
                : 'Not enough time — or order failed. Try again.';
      });
      return;
    }

    final afterSeconds = context.read<AppState>().spendableTimeSeconds;
    final afterDrinks = context.read<AppState>().drinksAllowanceRemaining;

    if (!payWithCash && !drink.isStandard) {
      await TimeRefillOverlay.show(
        context,
        fromSeconds: beforeSeconds,
        toSeconds: afterSeconds,
        title: 'ROUND POURED',
        subtitle: '${drink.name} · −${drink.timeCostSeconds ~/ 60} min',
      );
    } else if (drink.isStandard) {
      await TimeRefillOverlay.show(
        context,
        fromSeconds: beforeSeconds,
        toSeconds: afterSeconds,
        title: 'ROUND POURED',
        subtitle: '${drink.name} · package drink ($afterDrinks left, was $beforeDrinks)',
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payWithCash
              ? '${drink.name} — settle at the bar.'
              : '${drink.name} ordered!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final inside = state.sessionPhase == SessionPhase.insideClub;
    final canPackage = inside &&
        drink.isStandard &&
        state.drinksAllowanceRemaining > 0;
    final canMinutes = inside &&
        !drink.isStandard &&
        state.spendableTimeSeconds >= drink.timeCostSeconds;
    final canCash = inside && !drink.isStandard;
    final blocked = _ordering || state.isWalletBusy;

    String primaryLabel;
    if (!inside) {
      primaryLabel = 'ENTER CLUB FIRST';
    } else if (drink.isStandard) {
      primaryLabel = canPackage ? 'ORDER (PACKAGE)' : 'NO DRINKS LEFT';
    } else if (canMinutes) {
      primaryLabel = 'ORDER (−${drink.timeCostSeconds ~/ 60} MIN)';
    } else {
      primaryLabel = 'NOT ENOUGH TIME';
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
                  colors: [Color(drink.imageColorStart), Color(drink.imageColorEnd)],
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
                child: Text(drink.badge!, style: const TextStyle(fontSize: 9, color: AppColors.goldBright)),
              ),
            Text(drink.name, style: Theme.of(context).textTheme.headlineMedium),
            Text(
              '${drink.flavor} • ${drink.abv}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.goldBright),
            ),
            const SizedBox(height: 12),
            Text(drink.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('INGREDIENTS', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9)),
            const SizedBox(height: 8),
            ...drink.ingredients.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: AppColors.goldBrushed),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11))),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.tigerRed,
                      ),
                ),
                Text(
                  drink.isStandard
                      ? 'Uses 1 package drink · ${state.drinksAllowanceRemaining} left'
                      : '−${drink.timeCostSeconds ~/ 60} min · or pay at bar',
                  style: TextStyle(
                    color: drink.isStandard
                        ? AppColors.timerHealthy
                        : AppColors.tigerRed,
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
                style: const TextStyle(color: AppColors.tigerOrange, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            TigerButton(
              label: primaryLabel,
              icon: Icons.local_bar,
              isLoading: _ordering,
              onPressed: (!blocked && (canPackage || canMinutes))
                  ? () => _order(payWithCash: false)
                  : null,
            ),
            if (!drink.isStandard) ...[
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
