import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/time_refill_overlay.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';
import '../../services/payment_service.dart';

class BuyTimeCheckoutScreen extends StatefulWidget {
  const BuyTimeCheckoutScreen({super.key});

  @override
  State<BuyTimeCheckoutScreen> createState() => _BuyTimeCheckoutScreenState();
}

class _BuyTimeCheckoutScreenState extends State<BuyTimeCheckoutScreen> {
  @override
  void initState() {
    super.initState();
    _processCheckout();
  }

  Future<void> _processCheckout() async {
    final state = context.read<AppState>();
    final minutes = state.selectedTimeMinutes;
    final beforeSeconds = state.activeTimeSeconds;
    final result = await state.purchaseTime(minutes);

    if (!mounted) return;

    if (result == PaymentResult.success) {
      final afterSeconds = state.activeTimeSeconds;
      await TimeRefillOverlay.show(
        context,
        fromSeconds: beforeSeconds,
        toSeconds: afterSeconds,
        title: 'TIME LOADED',
        subtitle: '$minutes minutes added to your balance',
      );
      if (!mounted) return;

      final phase = state.sessionPhase;
      if (phase == SessionPhase.insideClub) {
        context.go('/lounge');
      } else if (phase == SessionPhase.paidAwaitingEntry) {
        context.go('/entry');
      } else if (phase == SessionPhase.awaitingExitScan) {
        context.go('/exit');
      } else {
        context.go('/pricing');
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment failed. Please try again.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: LatticeBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.goldBrushed,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PROCESSING TIME PURCHASE...',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${state.selectedTimeMinutes}m • ${state.paymentMethod.label}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
