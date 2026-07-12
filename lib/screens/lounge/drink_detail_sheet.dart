import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/time_refill_overlay.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';

class DrinkDetailSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canOrder = state.sessionPhase == SessionPhase.insideClub &&
        state.canSpendTime &&
        state.spendableTimeSeconds >= drink.timeCostSeconds;

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
                Text(drink.price, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.goldBright)),
                Text(
                  '-${drink.timeCostSeconds ~/ 60} min',
                  style: const TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TigerButton(
              label: canOrder ? 'ORDER NOW' : 'NOT ENOUGH TIME',
              icon: Icons.local_bar,
              onPressed: canOrder
                  ? () async {
                      final appState = context.read<AppState>();
                      final beforeSeconds = appState.spendableTimeSeconds;
                      final ok = await appState.orderDrink(drink);
                      if (!context.mounted || !ok) return;

                      final afterSeconds = context.read<AppState>().spendableTimeSeconds;
                      await TimeRefillOverlay.show(
                        context,
                        fromSeconds: beforeSeconds,
                        toSeconds: afterSeconds,
                        title: 'ROUND POURED',
                        subtitle: '${drink.name} · −${drink.timeCostSeconds ~/ 60} min',
                      );

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${drink.name} ordered!')),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
