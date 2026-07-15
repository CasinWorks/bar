import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/time_refill_overlay.dart';
import '../../providers/app_state.dart';
import '../../models/club_session.dart';
import '../../services/payment_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    _processCheckout();
  }

  Future<void> _processCheckout() async {
    final state = context.read<AppState>();

    if (!state.canPurchaseNewPass) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You still have time on your account. Use your balance, or ask the house to load more.'),
        ),
      );
      context.go('/pricing');
      return;
    }

    final beforeSeconds = state.activeTimeSeconds;
    final result = await state.purchasePass();

    if (!mounted) return;

    if (result == PaymentResult.success) {
      final afterSeconds = state.activeTimeSeconds;
      await TimeRefillOverlay.show(
        context,
        fromSeconds: beforeSeconds,
        toSeconds: afterSeconds,
        title: 'PASS SECURED',
        subtitle: 'Your time balance is updating',
      );
      if (!mounted) return;

      final phase = state.sessionPhase;
      if (phase == SessionPhase.insideClub) {
        context.go('/lounge');
      } else if (phase == SessionPhase.awaitingExitScan) {
        context.go('/exit');
      } else {
        context.go('/entry');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed. Please try again.')),
      );
      context.go('/pricing');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'SECURING MEMBER PASS...',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'PROVISIONING SMART ID #7 • THE BLIND TIGER',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
