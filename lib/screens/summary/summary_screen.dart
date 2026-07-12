import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;

    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: AppColors.successGreen, size: 48),
                const SizedBox(height: 12),
                Text('CHECKOUT COMPLETE', style: Theme.of(context).textTheme.headlineLarge),
                Text(
                  'Thank you for visiting The Blind Tiger.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (state.timeBalance > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${state.formatDuration(state.timeBalance)} saved to your time balance for your next visit.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.successGreen,
                          fontSize: 11,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (session != null)
                  LuxuryCard(
                    child: Column(
                      children: [
                        _Row('Member', session.memberName),
                        _Row('Branch', session.branch),
                        _Row('Pass', '${session.purchasedSeconds ~/ 60} minutes'),
                        _Row('Paid', '₱${session.amountPaid}'),
                        _Row('Time remaining', state.formatDuration(session.remainingSeconds)),
                        _Row('Drinks ordered', '${session.drinksOrdered}'),
                        if (session.enteredAt != null)
                          _Row('Entered', _formatTime(session.enteredAt!)),
                        if (session.exitedAt != null)
                          _Row('Exited', _formatTime(session.exitedAt!)),
                      ],
                    ),
                  ),
                const Spacer(),
                if (state.canPurchaseNewPass)
                  TigerButton(
                    label: 'PURCHASE NEW PASS',
                    icon: Icons.add_circle_outline,
                    onPressed: () {
                      state.beginNewVisit();
                      context.go('/pricing');
                    },
                  )
                else ...[
                  TigerButton(
                    label: 'USE MY TIME BALANCE',
                    icon: Icons.account_balance_wallet,
                    onPressed: () {
                      state.beginNewVisit();
                      context.go('/pricing');
                    },
                  ),
                  const SizedBox(height: 12),
                  TigerButton(
                    label: 'BUY TIME',
                    icon: Icons.bolt,
                    secondary: true,
                    onPressed: () {
                      state.beginNewVisit();
                      context.push('/buy-time');
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await state.logout();
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
